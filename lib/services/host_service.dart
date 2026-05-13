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
  bool get isServerRunning => _server != null;
  final List<WebSocketChannel>        _clients     = [];
  final Map<WebSocketChannel, String> _clientNames = {};
  String? _hostName;
  Timer? _pingTimer;
  bool _isShuttingDown = false;

  final _payloadController    = StreamController<SharePayload>.broadcast();
  final _clientListController = StreamController<List<String>>.broadcast();
  final _statusController     = StreamController<String>.broadcast();

  Stream<SharePayload>  get payloadStream    => _payloadController.stream;
  Stream<List<String>>  get clientListStream => _clientListController.stream;
  Stream<String>        get statusStream     => _statusController.stream;

  Future<void> startServer(int port, String hostName, Router router) async {
    await stopServer();
    _hostName = hostName;
    _isShuttingDown = false;

    // Register WS route BEFORE server starts
    router.get('/ws', webSocketHandler((WebSocketChannel channel, String? protocol) {
      if (_isShuttingDown) {
        try { channel.sink.close(); } catch (_) {}
        return;
      }

      _clients.add(channel);
      _statusController.add('Client connected. Total: ${_clients.length}');

      channel.stream.listen(
        (message) {
          if (message is String) {
            // CRITICAL FIX: handle in microtask to prevent blocking event loop
            Future.microtask(() => _handleMessage(message, channel));
          }
        },
        onDone:  () => _removeClient(channel),
        onError: (_) => _removeClient(channel),
        cancelOnError: true,
      );
    }));

    final handler = const Pipeline().addHandler(router.call);
    _server = await shelf_io.serve(handler, '0.0.0.0', port);
    print('[HostService] Server running on 0.0.0.0:$port');

    // Ping every 30s — keeps connections alive without flooding
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isShuttingDown) return;
      _broadcastAll(jsonEncode({'type': 'ping'}));
    });
  }

  void _handleMessage(String message, WebSocketChannel sender) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['type'] == 'ping') return;

      if (data['type'] == 'handshake') {
        _clientNames[sender] = (data['senderName'] as String?) ?? 'Unknown';
        _emitClientList();
        _sendClientListTo(sender);
        return;
      }

      _payloadController.add(SharePayload.fromJson(data));

      for (final client in List<WebSocketChannel>.from(_clients)) {
        if (client != sender) {
          try {
            client.sink.add(message);
          } catch (_) {
            _removeClient(client);
          }
        }
      }
    } catch (e) {
      print('[HostService] Parse error: $e');
    }
  }

  void _removeClient(WebSocketChannel channel) {
    _clients.remove(channel);
    _clientNames.remove(channel);
    _emitClientList();
    _statusController.add('Client disconnected. Total: ${_clients.length}');
  }

  void _emitClientList() {
    final list = ['$_hostName (Host)', ..._clientNames.values];
    _clientListController.add(list);
    _broadcastAll(jsonEncode({'type': 'client_list', 'clients': list}));
  }

  void _sendClientListTo(WebSocketChannel channel) {
    final list = ['$_hostName (Host)', ..._clientNames.values];
    try {
      channel.sink.add(jsonEncode({'type': 'client_list', 'clients': list}));
    } catch (_) {}
  }

  void _broadcastAll(String message) {
    for (final client in List<WebSocketChannel>.from(_clients)) {
      try {
        client.sink.add(message);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  void sendPayload(SharePayload payload) {
    _broadcastAll(jsonEncode(payload.toJson()));
  }

  Future<void> stopServer() async {
    _isShuttingDown = true;
    _pingTimer?.cancel();
    _pingTimer = null;

    for (final client in List<WebSocketChannel>.from(_clients)) {
      try { await client.sink.close(); } catch (_) {}
    }
    _clients.clear();
    _clientNames.clear();
    _clientListController.add([]);

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _hostName = null;
    _isShuttingDown = false;
    print('[HostService] Server stopped');
  }

  void dispose() {
    _isShuttingDown = true;
    _pingTimer?.cancel();
    _pingTimer = null;

    for (final client in List<WebSocketChannel>.from(_clients)) {
      try { client.sink.close(); } catch (_) {}
    }
    _clients.clear();
    _clientNames.clear();

    _server?.close(force: true);
    _server = null;

    _payloadController.close();
    _clientListController.close();
    _statusController.close();
  }
}