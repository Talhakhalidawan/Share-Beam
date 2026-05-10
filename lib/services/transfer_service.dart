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

  // Emits incoming share payload (metadata and small files <1MB)
  final _payloadController = StreamController<SharePayload>.broadcast();
  Stream<SharePayload> get payloadStream => _payloadController.stream;

  // Emits download progress <id, progress_percentage>
  final _progressController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream => _progressController.stream;

  // Active client connection if this instance is acting as a client
  WebSocketChannel? _activeClientChannel;

  /// Start the Host Server
  Future<void> startServer(String hostIp, int port) async {
    final router = Router();

    // The Signaling Hub
    router.get('/ws', webSocketHandler((WebSocketChannel webSocket) {
      _clients.add(webSocket);
      webSocket.stream.listen(
        (message) => _handleIncomingMessage(message),
        onDone: () => _clients.remove(webSocket),
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
    _server = await shelf_io.serve(handler, hostIp, port);
  }

  /// Stop the Host Server
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
  Future<void> connectToHost(String ip, int port) async {
    final uri = Uri.parse('ws://$ip:$port/ws');
    _activeClientChannel = WebSocketChannel.connect(uri);
    _activeClientChannel!.stream.listen(
      (message) => _handleIncomingMessage(message),
      onDone: () {
        _activeClientChannel = null;
      },
      onError: (e) {
        print('WebSocket connection error: $e');
      }
    );
  }

  /// Disconnect as a Client
  void disconnectFromHost() {
    _activeClientChannel?.sink.close();
    _activeClientChannel = null;
  }

  /// Handles incoming JSON metadata string from WebSockets
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

  /// Send metadata (and payload data if < 1MB) via WebSocket.
  /// If it's a large file, pass the `fileToHost` so it can be served.
  Future<void> sendPayload(SharePayload payload, {File? fileToHost}) async {
    if (fileToHost != null) {
      _hostedFiles[payload.id] = fileToHost;
    }

    final messageJson = jsonEncode(payload.toJson());

    // Host sends to all connected clients
    for (var client in _clients) {
      client.sink.add(messageJson);
    }

    // Client sends to Host
    if (_activeClientChannel != null) {
      _activeClientChannel!.sink.add(messageJson);
    }
  }

  /// Receiver fetches a large file over HTTP using [id] from the `SharePayload`
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
        _progressController.add({id: 1.0}); // Done
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
