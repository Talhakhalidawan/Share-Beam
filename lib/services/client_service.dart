import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/models.dart';

class ClientService {
  WebSocketChannel? _channel;
  
  final _payloadController = StreamController<SharePayload>.broadcast();
  Stream<SharePayload> get payloadStream => _payloadController.stream;

  final _clientListController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get clientListStream => _clientListController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  /// Emits when the host drops the connection unexpectedly.
  final _disconnectedController = StreamController<void>.broadcast();
  Stream<void> get disconnectedStream => _disconnectedController.stream;

  /// Connects to a host at the given IP and port.
  Future<bool> connect(String ip, int port) async {
    disconnect();
    try {
      final uri = Uri.parse('ws://$ip:$port/ws');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      
      _statusController.add('Connected to $ip:$port');

      _channel!.stream.listen(
        (message) {
          if (message is String) {
            _handleIncomingMessage(message);
          }
        },
        onDone: () => _handleDisconnect(),
        onError: (e) => _handleDisconnect(),
      );
      return true;
    } catch (e) {
      print('[ClientService] Connection failed: $e');
      // Don't emit raw error to status — AppState handles friendly messages.
      return false;
    }
  }

  void _handleIncomingMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic>) return;

      if (data['type'] == 'client_list') {
        final List<dynamic> list = data['clients'] ?? [];
        _clientListController.add(list.cast<String>());
        return;
      }

      // Assume it's a SharePayload
      final payload = SharePayload.fromJson(data);
      _payloadController.add(payload);
    } catch (e) {
      print('[ClientService] Error parsing message: $e');
    }
  }

  void sendHandshake(String deviceName) {
    if (_channel == null) return;
    final message = jsonEncode({
      'type': 'handshake',
      'senderName': deviceName,
    });
    try {
      _channel!.sink.add(message);
    } catch (_) {}
  }

  void sendPayload(SharePayload payload) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(payload.toJson()));
    } catch (_) {}
  }

  void _handleDisconnect() {
    _channel = null;
    _statusController.add('Disconnected from host');
    _clientListController.add([]);
    _disconnectedController.add(null);
  }

  void disconnect() {
    _channel?.sink.close();
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
