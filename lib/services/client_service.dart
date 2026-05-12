import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../core/models.dart';

/// Robust WebSocket client with explicit TCP preflight, hard timeouts,
/// and automatic retry. Uses IOWebSocketChannel for Linux desktop compatibility.
class ClientService {
  WebSocketChannel? _channel;
  bool _isConnecting = false;

  final _payloadController     = StreamController<SharePayload>.broadcast();
  final _clientListController  = StreamController<List<String>>.broadcast();
  final _statusController      = StreamController<String>.broadcast();
  final _disconnectedController = StreamController<void>.broadcast();

  Stream<SharePayload>    get payloadStream      => _payloadController.stream;
  Stream<List<String>>    get clientListStream   => _clientListController.stream;
  Stream<String>          get statusStream       => _statusController.stream;
  Stream<void>            get disconnectedStream => _disconnectedController.stream;

  static const int      _maxAttempts    = 3;
  static const Duration _retryDelay     = Duration(seconds: 1);
  static const Duration _tcpTimeout     = Duration(seconds: 4);
  static const Duration _wsTimeout      = Duration(seconds: 6);

  /// Connects to host with TCP preflight + WebSocket upgrade.
  Future<bool> connect(String ip, int port) async {
    if (_isConnecting) {
      print('[ClientService] Connection already in progress, ignoring');
      return false;
    }

    disconnect();
    _isConnecting = true;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      Socket? tcpSocket;

      try {
        // ── STEP 1: TCP preflight ──────────────────────────────────────
        // Open raw TCP first to catch "No route to host" and routing issues
        // BEFORE attempting the WS upgrade.
        print('[ClientService] Attempt $attempt/$_maxAttempts — TCP preflight to $ip:$port');

        tcpSocket = await Socket.connect(ip, port, timeout: _tcpTimeout);
        print('[ClientService] TCP OK from ${tcpSocket.address.address}:${tcpSocket.port}');
        await tcpSocket.close();
        tcpSocket = null;

        // Small delay to let kernel settle route cache
        if (attempt > 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // ── STEP 2: WebSocket upgrade ──────────────────────────────────
        final uri = Uri.parse('ws://$ip:$port/ws');

        // IOWebSocketChannel uses dart:io WebSocket — more reliable on Linux
        _channel = IOWebSocketChannel.connect(
          uri,
          pingInterval: const Duration(seconds: 20),
          connectTimeout: _wsTimeout,
        );

        await _channel!.ready.timeout(_wsTimeout);

        print('[ClientService] WebSocket connected to $ip:$port');

        _channel!.stream.listen(
          (message) {
            if (message is String) _handleMessage(message);
          },
          onDone:  _handleDisconnect,
          onError: (e) {
            print('[ClientService] Stream error: $e');
            _handleDisconnect();
          },
        );

        _isConnecting = false;
        return true;

      } on SocketException catch (e) {
        print('[ClientService] TCP/WS failed attempt $attempt: $e');
        tcpSocket?.destroy();
        _cleanupChannel();
        if (attempt < _maxAttempts) await Future.delayed(_retryDelay);

      } on TimeoutException catch (e) {
        print('[ClientService] Timeout attempt $attempt: $e');
        tcpSocket?.destroy();
        _cleanupChannel();
        if (attempt < _maxAttempts) await Future.delayed(_retryDelay);

      } catch (e) {
        print('[ClientService] Unexpected error attempt $attempt: $e');
        tcpSocket?.destroy();
        _cleanupChannel();
        if (attempt < _maxAttempts) await Future.delayed(_retryDelay);
      }
    }

    _isConnecting = false;
    return false;
  }

  void _cleanupChannel() {
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
  }

  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic>) return;

      if (data['type'] == 'ping') return;

      if (data['type'] == 'client_list') {
        final list = (data['clients'] as List<dynamic>? ?? []).cast<String>();
        _clientListController.add(list);
        return;
      }

      _payloadController.add(SharePayload.fromJson(data));
    } catch (e) {
      print('[ClientService] Parse error: $e');
    }
  }

  void sendHandshake(String deviceName) {
    _send(jsonEncode({'type': 'handshake', 'senderName': deviceName}));
  }

  void sendPayload(SharePayload payload) {
    _send(jsonEncode(payload.toJson()));
  }

  void _send(String message) {
    if (_channel == null) return;
    try { _channel!.sink.add(message); } catch (_) {}
  }

  void _handleDisconnect() {
    _channel = null;
    _statusController.add('Disconnected from host');
    _clientListController.add([]);
    _disconnectedController.add(null);
  }

  void disconnect() {
    _isConnecting = false;
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
  }

  void dispose() {
    disconnect();
    _payloadController.close();
    _clientListController.close();
    _statusController.close();
    _disconnectedController.close();
  }
}