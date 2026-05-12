import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/models.dart';

class ClientService {
  WebSocketChannel? _channel;

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
  static const Duration _connectTimeout = Duration(seconds: 6);

  /// Tries to connect up to [_maxAttempts] times.
  ///
  /// Why retries help with `EHOSTUNREACH`:
  ///   The error usually means Linux's TCP SYN went out the wrong network
  ///   interface (e.g. Ethernet instead of Wi-Fi) because the routing table
  ///   prefers Ethernet for that subnet. After the first failure the kernel's
  ///   route cache is updated and subsequent attempts often succeed. Android
  ///   Wi-Fi power-save can also cause the first SYN to be dropped while the
  ///   radio wakes up; a retry after 1 s reliably catches it.
  Future<bool> connect(String ip, int port) async {
    disconnect();

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final uri = Uri.parse('ws://$ip:$port/ws');
        _channel = WebSocketChannel.connect(uri);

        // ready completes once the WS handshake is done or throws on failure.
        await _channel!.ready.timeout(_connectTimeout);

        _channel!.stream.listen(
          (message) {
            if (message is String) _handleMessage(message);
          },
          onDone:  _handleDisconnect,
          onError: (_) => _handleDisconnect(),
        );

        return true;
      } catch (e) {
        print('[ClientService] Attempt $attempt/$_maxAttempts failed: $e');
        try { await _channel?.sink.close(); } catch (_) {}
        _channel = null;

        if (attempt < _maxAttempts) {
          await Future.delayed(_retryDelay);
        }
      }
    }

    return false;
  }

  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic>) return;

      // Host keep-alive ping — no action needed.
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