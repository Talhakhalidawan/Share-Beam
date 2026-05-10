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
    // Stop any existing broadcast first to avoid conflicts.
    await stopHost();

    final service = BonsoirService(
      name: deviceName,
      type: serviceType,
      port: port,
      // Optional: add TXT records for additional info if needed.
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.start();
  }

  /// Stop advertising.
  Future<void> stopHost() async {
    if (_broadcast == null) return;
    try {
      await _broadcast!.stop();
    } catch (e) {
      print('[DiscoveryService] Error stopping broadcast: $e');
    }
    _broadcast = null;
  }

  /// Begin scanning for other ShareBeam hosts.
  Future<void> startDiscovery() async {
    // Stop any running discovery first.
    await stopDiscovery();

    _discovery = BonsoirDiscovery(type: serviceType);

    // The eventStream could be null if the platform doesn't support mDNS (web).
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

          // Remove any existing entry with same ip & port to avoid duplicates.
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

  /// Stop scanning for hosts and clear the device list.
  Future<void> stopDiscovery() async {
    if (_discovery == null) return;
    try {
      await _discovery!.stop();
    } catch (e) {
      print('[DiscoveryService] Error stopping discovery: $e');
    }
    _discovery = null;
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  /// Clean up all resources.
  void dispose() {
    stopHost();
    stopDiscovery();
    _devicesController.close();
  }
}