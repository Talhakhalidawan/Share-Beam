import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/models.dart';

class TransferService {
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];
  final Map<String, File> _hostedFiles = {};

  final _payloadController = StreamController<SharePayload>.broadcast();
  Stream<SharePayload> get payloadStream => _payloadController.stream;

  final _progressController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream => _progressController.stream;

  // Track connection status
  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

  WebSocketChannel? _activeClientChannel;

  /// Start the Host Server - binds to 0.0.0.0 so all interfaces are reachable
  Future<void> startServer(int port) async {
    final router = Router();

    // The Signaling Hub
    router.get('/ws', webSocketHandler((WebSocketChannel webSocket, String? protocol) {
      _clients.add(webSocket);
      _connectionStatusController.add('Client connected. Total: ${_clients.length}');
      webSocket.stream.listen(
        (message) => _handleIncomingMessage(message),
        onDone: () {
          _clients.remove(webSocket);
          _connectionStatusController.add('Client disconnected. Total: ${_clients.length}');
        },
      );
    }));

    // Large file download endpoint
    router.get('/download/<id>', (Request request, String id) async {
      final file = _hostedFiles[id];
      if (file == null || !await file.exists()) {
        return Response.notFound('File not found');
      }

      final stat = await file.stat();
      final fileStream = file.openRead();

      return Response.ok(
        fileStream,
        headers: {
          'Content-Length': stat.size.toString(),
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="${file.uri.pathSegments.last}"',
        },
      );
    });

    final handler = const Pipeline().addHandler(router.call);
    // Bind to 0.0.0.0 so other devices on the LAN can reach us
    _server = await shelf_io.serve(handler, '0.0.0.0', port);
    print('[TransferService] Server running on 0.0.0.0:$port');
  }

  Future<void> stopServer() async {
    for (var client in _clients) {
      await client.sink.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _hostedFiles.clear();
  }

  /// Connect as a Client (Receiver) to a Host
  Future<bool> connectToHost(String ip, int port) async {
    try {
      final uri = Uri.parse('ws://$ip:$port/ws');
      _activeClientChannel = WebSocketChannel.connect(uri);
      // Wait for the connection to actually establish
      await _activeClientChannel!.ready;
      
      _connectionStatusController.add('Connected to $ip:$port');

      _activeClientChannel!.stream.listen(
        (message) => _handleIncomingMessage(message),
        onDone: () {
          _activeClientChannel = null;
          _connectionStatusController.add('Disconnected from host');
        },
        onError: (e) {
          print('WebSocket stream error: $e');
          _connectionStatusController.add('Connection error: $e');
        },
      );
      return true;
    } catch (e) {
      print('WebSocket connect error: $e');
      _connectionStatusController.add('Failed to connect: $e');
      _activeClientChannel = null;
      return false;
    }
  }

  void disconnectFromHost() {
    _activeClientChannel?.sink.close();
    _activeClientChannel = null;
  }

  void _handleIncomingMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        final payload = SharePayload.fromJson(data);
        _payloadController.add(payload);
      } catch (e) {
        print('Error decoding share payload: $e');
      }
    }
  }

  Future<void> sendPayload(SharePayload payload, {File? fileToHost}) async {
    if (fileToHost != null) {
      _hostedFiles[payload.id] = fileToHost;
    }

    final messageJson = jsonEncode(payload.toJson());

    for (var client in _clients) {
      client.sink.add(messageJson);
    }

    if (_activeClientChannel != null) {
      _activeClientChannel!.sink.add(messageJson);
    }
  }

  Future<File?> downloadFile(String ip, int port, String id, String fileName, String saveDirectory) async {
    final url = Uri.parse('http://$ip:$port/download/$id');
    final httpClient = HttpClient();
    
    try {
      final request = await httpClient.getUrl(url);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        final savePath = '$saveDirectory/$fileName';
        final file = File(savePath);
        final sink = file.openWrite();
        
        int receivedBytes = 0;
        
        await for (var chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          
          if (contentLength > 0) {
             final progress = receivedBytes / contentLength;
             _progressController.add({id: progress});
          }
        }
        
        await sink.close();
        _progressController.add({id: 1.0});
        return file;
      }
    } catch (e) {
      print('HTTP File Download error: $e');
    } finally {
      httpClient.close();
    }
    return null;
  }
}
