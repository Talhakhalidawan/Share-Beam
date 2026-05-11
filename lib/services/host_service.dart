import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/models.dart';

class HostService {
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];
  final Map<WebSocketChannel, String> _clientNames = {};
  String? _hostName;

  final _payloadController = StreamController<SharePayload>.broadcast();
  Stream<SharePayload> get payloadStream => _payloadController.stream;

  final _clientListController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get clientListStream => _clientListController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  /// Starts the WebSocket and HTTP server on the given port.
  Future<void> startServer(int port, String hostName, Router router) async {
    await stopServer();
    _hostName = hostName;

    // Add WebSocket handler to the provided router
    router.get('/ws', webSocketHandler((WebSocketChannel channel, String? protocol) {
      _clients.add(channel);
      _statusController.add('Client connected. Total: ${_clients.length}');

      channel.stream.listen(
        (message) {
          if (message is String) {
            _handleIncomingMessage(message, channel);
          }
        },
        onDone: () => _removeClient(channel),
        onError: (e) => _removeClient(channel),
      );
    }));

    final handler = const Pipeline().addHandler(router.call);
    _server = await shelf_io.serve(handler, '0.0.0.0', port);
    print('[HostService] Server running on 0.0.0.0:$port');
  }

  void _handleIncomingMessage(String message, WebSocketChannel sender) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      
      // Handle Handshake
      if (data['type'] == 'handshake') {
        final name = data['senderName'] ?? 'Unknown';
        _clientNames[sender] = name;
        _emitConnectedClients();
        _sendClientListTo(sender);
        return;
      }

      // Handle SharePayload - Relay to others
      final payload = SharePayload.fromJson(data);
      _payloadController.add(payload);
      
      for (final client in _clients) {
        if (client != sender) {
          try {
            client.sink.add(message);
          } catch (_) {
            _removeClient(client);
          }
        }
      }
    } catch (e) {
      print('[HostService] Error parsing message: $e');
    }
  }

  void _removeClient(WebSocketChannel channel) {
    _clients.remove(channel);
    _clientNames.remove(channel);
    _emitConnectedClients();
    _statusController.add('Client disconnected. Total: ${_clients.length}');
  }

  void _emitConnectedClients() {
    final names = _clientNames.values.toList();
    final fullList = ['$_hostName (Host)', ...names];
    _clientListController.add(fullList);
    _broadcastToAll(jsonEncode({'type': 'client_list', 'clients': fullList}));
  }

  void _sendClientListTo(WebSocketChannel channel) {
    final names = _clientNames.values.toList();
    final fullList = ['$_hostName (Host)', ...names];
    final message = jsonEncode({'type': 'client_list', 'clients': fullList});
    try {
      channel.sink.add(message);
    } catch (_) {}
  }

  void _broadcastToAll(String message) {
    for (final client in List<WebSocketChannel>.from(_clients)) {
      try {
        client.sink.add(message);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  /// Sends a payload to all connected clients.
  void sendPayload(SharePayload payload) {
    final message = jsonEncode(payload.toJson());
    _broadcastToAll(message);
  }

  Future<void> stopServer() async {
    for (final client in List<WebSocketChannel>.from(_clients)) {
      try {
        await client.sink.close();
      } catch (_) {}
    }
    _clients.clear();
    _clientNames.clear();
    _clientListController.add([]);
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _hostName = null;
  }

  void dispose() {
    stopServer();
    _payloadController.close();
    _clientListController.close();
    _statusController.close();
  }
}
