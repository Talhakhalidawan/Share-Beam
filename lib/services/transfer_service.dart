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

  final _progressController =
      StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream =>
      _progressController.stream;

  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  WebSocketChannel? _activeClientChannel;

  /// Start the host server on [port] bound to all network interfaces.
  Future<void> startServer(int port) async {
    // Stop any existing server first.
    await stopServer();

    final router = Router();

    // WebSocket signaling hub at /ws
    router.get('/ws', webSocketHandler((WebSocketChannel channel, String? protocol) {
      _clients.add(channel);
      _connectionStatusController
          .add('Client connected. Total: ${_clients.length}');

      channel.stream.listen(
        (message) {
          // Process message locally
          _handleIncomingMessage(message);

          // Relay to all OTHER connected clients (hub behaviour)
          final data = message is String ? message : null;
          if (data == null) return; // ignore binary
          for (final client in _clients) {
            if (client != channel) {
              try {
                client.sink.add(data);
              } catch (e) {
                // Failed to send, remove client
                _clients.remove(client);
                _connectionStatusController
                    .add('Client removed (send error). Total: ${_clients.length}');
              }
            }
          }
        },
        onDone: () {
          _clients.remove(channel);
          _connectionStatusController
              .add('Client disconnected. Total: ${_clients.length}');
        },
        onError: (e) {
          print('[TransferService] WebSocket stream error: $e');
          _clients.remove(channel);
        },
      );
    }));

    // HTTP endpoint for large file downloads (stub for later)
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
    _connectionStatusController
        .add('Host server started on port $port');
    print('[TransferService] Server running on 0.0.0.0:$port');
  }

  /// Shut down the host server and disconnect all clients.
  Future<void> stopServer() async {
    // Close all WebSocket connections
    for (final client in _clients) {
      try {
        await client.sink.close();
      } catch (_) {}
    }
    _clients.clear();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _hostedFiles.clear();
  }

  /// Connect this device as a client to a remote host at [ip]:[port].
  Future<bool> connectToHost(String ip, int port) async {
    // Disconnect any existing connection first.
    disconnectFromHost();

    try {
      final uri = Uri.parse('ws://$ip:$port/ws');
      _activeClientChannel = WebSocketChannel.connect(uri);
      await _activeClientChannel!.ready;

      _connectionStatusController.add('Connected to $ip:$port');

      _activeClientChannel!.stream.listen(
        (message) => _handleIncomingMessage(message),
        onDone: () {
          _activeClientChannel = null;
          _connectionStatusController.add('Disconnected from host');
        },
        onError: (e) {
          print('[TransferService] WebSocket error: $e');
          _connectionStatusController.add('Connection error: $e');
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

  /// Disconnect from the remote host.
  void disconnectFromHost() {
    if (_activeClientChannel == null) return;
    _activeClientChannel!.sink.close();
    _activeClientChannel = null;
  }

  /// Process an incoming WebSocket message (JSON string) into a SharePayload
  /// and add it to the local stream.
  void _handleIncomingMessage(dynamic message) {
    if (message is! String) return;
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final payload = SharePayload.fromJson(data);
      _payloadController.add(payload);
    } catch (e) {
      print('[TransferService] Error decoding payload: $e');
    }
  }

  /// Send a [payload] to all connected clients (if hosting) or to the host
  /// (if a client). For file transfers, register the [fileToHost] for future
  /// HTTP downloads.
  Future<void> sendPayload(SharePayload payload, {File? fileToHost}) async {
    if (fileToHost != null) {
      _hostedFiles[payload.id] = fileToHost;
    }

    final messageJson = jsonEncode(payload.toJson());

    // If we are hosting, send to all connected clients.
    if (_clients.isNotEmpty) {
      for (final client in List<WebSocketChannel>.from(_clients)) {
        try {
          client.sink.add(messageJson);
        } catch (_) {
          _clients.remove(client);
        }
      }
    }

    // If we are a client, send to the host.
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

  /// Download a large file from a remote host (stub for later).
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
            final progress = receivedBytes / contentLength;
            _progressController.add({id: progress});
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

  /// Clean up all resources.
  void dispose() {
    stopServer();
    disconnectFromHost();
    _payloadController.close();
    _progressController.close();
    _connectionStatusController.close();
  }
}