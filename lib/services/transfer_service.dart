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
  final Map<WebSocketChannel, String> _clientNames = {}; // channel -> device name
  final Map<String, File> _hostedFiles = {};

  final _payloadController = StreamController<SharePayload>.broadcast();
  Stream<SharePayload> get payloadStream => _payloadController.stream;

  final _progressController =
      StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream =>
      _progressController.stream;

  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  // Stream of current connected client names (for the host)
  final _connectedClientsController =
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get connectedClientsStream =>
      _connectedClientsController.stream;

  WebSocketChannel? _activeClientChannel;

  Future<void> startServer(int port) async {
    await stopServer();

    final router = Router();

    router.get('/ws', webSocketHandler((WebSocketChannel channel, String? protocol) {
      _clients.add(channel);
      _connectionStatusController
          .add('Client connected. Total: ${_clients.length}');

      channel.stream.listen(
        (message) {
          if (message is String) {
            try {
              final data = jsonDecode(message);
              if (data is! Map<String, dynamic>) return;   // ignore non-map messages

              // Check for handshake
              if (data['type'] == 'handshake') {
                final name = data['senderName'] ?? 'Unknown';
                _clientNames[channel] = name;
                _emitConnectedClients();
                return;
              }

              // Try to parse as SharePayload
              final payload = SharePayload.fromJson(data);
              _payloadController.add(payload);

              final encoded = message;
              for (final client in _clients) {
                if (client != channel) {
                  try {
                    client.sink.add(encoded);
                  } catch (_) {
                    _clients.remove(client);
                    _clientNames.remove(client);
                    _emitConnectedClients();
                  }
                }
              }
            } catch (e) {
              // Ignore malformed messages
              print('[TransferService] Ignoring malformed message: $e');
            }
          }
        },
        onDone: () {
          _clients.remove(channel);
          _clientNames.remove(channel);
          _emitConnectedClients();
          _connectionStatusController
              .add('Client disconnected. Total: ${_clients.length}');
        },
        onError: (e) {
          print('[TransferService] WebSocket error: $e');
          _clients.remove(channel);
          _clientNames.remove(channel);
          _emitConnectedClients();
        },
      );
    }));

    // file download endpoint (stub)
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
          'Content-Disposition':
              'attachment; filename="${file.uri.pathSegments.last}"',
        },
      );
    });

    final handler = const Pipeline().addHandler(router.call);
    _server = await shelf_io.serve(handler, '0.0.0.0', port);
    print('[TransferService] Server running on 0.0.0.0:$port');
  }

  void _emitConnectedClients() {
    final names = _clientNames.values.toList();
    _connectedClientsController.add(names);
  }

  Future<void> stopServer() async {
    for (final client in _clients) {
      try {
        await client.sink.close();
      } catch (_) {}
    }
    _clients.clear();
    _clientNames.clear();
    _emitConnectedClients();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _hostedFiles.clear();
  }

  Future<bool> connectToHost(String ip, int port) async {
    disconnectFromHost();
    try {
      final uri = Uri.parse('ws://$ip:$port/ws');
      _activeClientChannel = WebSocketChannel.connect(uri);
      await _activeClientChannel!.ready;

      // Send handshake with our device name (AppState will provide it)
      // We'll need a reference to the device name; we'll do that via sendHandshake.
      // For now, we'll leave a placeholder; the AppState will call sendHandshake after connecting.
      // We'll adjust connectToHost to accept a deviceName.
      // Instead, let's add a method sendHandshake that AppState calls after connect.
      
      _connectionStatusController.add('Connected to $ip:$port');

      _activeClientChannel!.stream.listen(
        (message) {
          if (message is String) {
            try {
              final data = jsonDecode(message);
              final payload = SharePayload.fromJson(data);
              _payloadController.add(payload);
            } catch (e) {
              print('[TransferService] Error decoding payload: $e');
            }
          }
        },
        onDone: () {
          _activeClientChannel = null;
          _connectionStatusController.add('Disconnected from host');
        },
        onError: (e) {
          print('[TransferService] WebSocket error: $e');
          _activeClientChannel?.sink.close();
          _activeClientChannel = null;
        },
      );
      return true;
    } catch (e) {
      print('[TransferService] WebSocket connect error: $e');
      _connectionStatusController.add('Failed to connect: $e');
      _activeClientChannel = null;
      return false;
    }
  }

  /// Send a handshake message (must be called right after connectToHost succeeds).
  void sendHandshake(String deviceName) {
    if (_activeClientChannel == null) return;
    final handshake = jsonEncode({
      'type': 'handshake',
      'senderName': deviceName,
    });
    try {
      _activeClientChannel!.sink.add(handshake);
    } catch (e) {
      print('[TransferService] Handshake failed: $e');
    }
  }

  void disconnectFromHost() {
    if (_activeClientChannel == null) return;
    _activeClientChannel!.sink.close();
    _activeClientChannel = null;
  }

  Future<void> sendPayload(SharePayload payload, {File? fileToHost}) async {
    if (fileToHost != null) {
      _hostedFiles[payload.id] = fileToHost;
    }

    final messageJson = jsonEncode(payload.toJson());

    // If hosting, send to all clients
    for (final client in List<WebSocketChannel>.from(_clients)) {
      try {
        client.sink.add(messageJson);
      } catch (_) {
        _clients.remove(client);
        _clientNames.remove(client);
        _emitConnectedClients();
      }
    }

    // If client, send to host
    if (_activeClientChannel != null) {
      try {
        _activeClientChannel!.sink.add(messageJson);
      } catch (e) {
        print('[TransferService] Failed to send to host: $e');
        _activeClientChannel?.sink.close();
        _activeClientChannel = null;
      }
    }
  }

  Future<File?> downloadFile(
      String ip, int port, String id, String fileName, String saveDirectory) async {
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
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (contentLength > 0) {
            _progressController.add({id: receivedBytes / contentLength});
          }
        }
        await sink.close();
        _progressController.add({id: 1.0});
        return file;
      }
    } catch (e) {
      print('[TransferService] HTTP download error: $e');
    } finally {
      httpClient.close();
    }
    return null;
  }

  void dispose() {
    stopServer();
    disconnectFromHost();
    _payloadController.close();
    _progressController.close();
    _connectionStatusController.close();
    _connectedClientsController.close();
  }
}