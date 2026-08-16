import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';
import '../models/server_info.dart';

class NsdService {
  static NsdService? _instance;
  Discovery? _discovery;
  final _serversController = StreamController<List<ServerInfo>>.broadcast();
  final List<ServerInfo> _discovered = [];
  bool _isScanning = false;

  NsdService._();

  static NsdService get instance {
    _instance ??= NsdService._();
    return _instance!;
  }

  bool get isScanning => _isScanning;
  List<ServerInfo> get discoveredServers => List.unmodifiable(_discovered);
  Stream<List<ServerInfo>> get serversStream => _serversController.stream;


  Future<void> startScan() async {
    if (_isScanning) return;

    _discovered.clear();
    _isScanning = true;
    _serversController.add([]);

    try {
      _discovery = await startDiscovery('_smb._tcp',
          ipLookupType: IpLookupType.v4);
      _discovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          _onServiceFound(service);
        }
      });
    } catch (e) {
      debugPrint('NSD error: $e');
      _isScanning = false;
    }
  }

  void _onServiceFound(Service service) {
    final host = service.host;
    final name = service.name ?? 'Unknown Server';
    final port = service.port ?? 445;

    if (host == null) return;

    final server = ServerInfo(
      name: name,
      host: host,
      port: port,
    );

   
    if (!_discovered.any((s) => s.host == host)) {
      _discovered.add(server);
      _serversController.add(List.from(_discovered));
      debugPrint('Found SMB server: $name @ $host:$port');
    }
  }


  Future<void> stopScan() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
    _isScanning = false;
  }

 
  void dispose() {
    stopScan();
    _serversController.close();
  }
}
