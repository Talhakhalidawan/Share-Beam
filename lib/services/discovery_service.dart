import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import '../core/models.dart';

class DiscoveryService {
  final String serviceType = '_sharebeam._tcp';
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  
  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  
  final List<DiscoveredDevice> _discoveredDevices = [];

  Future<void> startHost(String deviceName, int port) async {
    BonsoirService service = BonsoirService(
      name: deviceName,
      type: serviceType,
      port: port,
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
  }

  Future<void> stopHost() async {
    if (_broadcast != null) {
      await _broadcast!.stop();
      _broadcast = null;
    }
  }

  Future<void> startDiscovery() async {
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.ready;
    
    _discovery!.eventStream!.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        if (event.service != null) {
          event.service!.resolve(_discovery!.serviceResolver);
        }
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        if (event.service != null && event.service is ResolvedBonsoirService) {
          final resolved = event.service as ResolvedBonsoirService;
          final host = resolved.host;
          if (host != null && host.isNotEmpty) {
            _discoveredDevices.removeWhere((d) => d.ip == host);
            _discoveredDevices.add(DiscoveredDevice(
              name: resolved.name,
              ip: host,
              port: resolved.port,
            ));
            _devicesController.add(List.from(_discoveredDevices));
          }
        }
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        if (event.service != null) {
           _discoveredDevices.removeWhere((d) => d.name == event.service!.name);
           _devicesController.add(List.from(_discoveredDevices));
        }
      }
    });

    await _discovery!.start();
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await _discovery!.stop();
      _discovery = null;
    }
    _discoveredDevices.clear();
    _devicesController.add([]);
  }
}
