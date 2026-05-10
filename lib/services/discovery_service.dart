import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import '../core/models.dart';

class DiscoveryService {
  final String serviceType = '_sharebeam._tcp';
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream =>
      _devicesController.stream;

  final List<DiscoveredDevice> _discoveredDevices = [];

  /// Start advertising this device on the local network.
  Future<void> startHost(String deviceName, int port) async {
    // If already broadcasting, skip.
    if (_broadcast != null) return;

    final service = BonsoirService(
      name: deviceName,
      type: serviceType,
      port: port,
    );

    try {
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.start();
    } catch (e) {
      print('[DiscoveryService] Error starting broadcast: $e');
      _broadcast = null;  // mark as failed, no rethrow
      // AppState will simply show a warning, but the server remains active.
    }
  }

  Future<void> stopHost() async {
    if (_broadcast == null) return;
    try {
      await _broadcast!.stop();
    } catch (e) {
      print('[DiscoveryService] Warning (stopHost): $e');
    }
    _broadcast = null;
  }

  Future<void> startDiscovery() async {
    await stopDiscovery();

    _discovery = BonsoirDiscovery(type: serviceType);

    final stream = _discovery!.eventStream;
    if (stream == null) {
      print('[DiscoveryService] mDNS discovery not available on this platform.');
      return;
    }

    stream.listen(
      (event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          final service = event.service;
          if (service != null) {
            service.resolve(_discovery!.serviceResolver);
          }
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final resolved = event.service;
          if (resolved == null) return;
          final host = resolved.host;
          if (host == null || host.isEmpty) return;

          _discoveredDevices.removeWhere(
            (d) => d.ip == host && d.port == resolved.port,
          );
          _discoveredDevices.add(
            DiscoveredDevice(
              name: resolved.name,
              ip: host,
              port: resolved.port,
            ),
          );
          _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          final lostService = event.service;
          if (lostService == null) return;
          final host = lostService.host ?? '';
          _discoveredDevices.removeWhere(
            (d) => d.ip == host && d.port == lostService.port,
          );
          _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
        }
      },
      onError: (e) {
        print('[DiscoveryService] Discovery stream error: $e');
      },
      cancelOnError: false,
    );

    await _discovery!.start();
  }

  Future<void> stopDiscovery() async {
    if (_discovery == null) return;
    try {
      await _discovery!.stop();
    } catch (e) {
      print('[DiscoveryService] Warning (stopDiscovery): $e');
    }
    _discovery = null;
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  void dispose() {
    stopHost();
    stopDiscovery();
    _devicesController.close();
  }
}