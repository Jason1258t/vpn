import 'dart:async';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vpn/vpn_status.dart';

class VpnRepository {
  late final FlutterV2ray _v2ray;
  final BehaviorSubject<VpnStatus> status;

  final List<V2RayURL> _configs = [
    FlutterV2ray.parseFromURL(dotenv.get("BASE_URL")),
  ];

  VpnRepository() : status = BehaviorSubject.seeded(VpnStatus.disconnected) {
    _v2ray = FlutterV2ray(
      onStatusChanged: (v2rayStatus) {
        status.add(_mapStatus(v2rayStatus.state));
      },
    );

    _initialize();
  }

  Future<void> _initialize() async {
    await _v2ray.initializeV2Ray();
  }

  VpnStatus _mapStatus(String state) {
    switch (state.toLowerCase()) {
      case 'connected':
        return VpnStatus.connected;
      case 'connecting':
      case 'reconnecting':
        return VpnStatus.connection;
      default:
        return VpnStatus.disconnected;
    }
  }

  Future<void> connect() async {
    if (_configs.isEmpty) {
      log('configs is empty');
      return;
    }

    final config = _configs.first;
    if (await _v2ray.requestPermission()) {
      await _v2ray.startV2Ray(
        remark: 'Server ${config.remark}',
        config: config.getFullConfiguration(),
        proxyOnly: false,
      );
    }
  }

  Future<void> disconnect() async {
    await _v2ray.stopV2Ray();
  }

  Future<int> ping() async {
    log("ping requested");
    try {
      final result = (await status.last) == VpnStatus.connected
          ? await _getPingConnected()
          : await _getPingToBaseServer();

      log("ping: $result ms");
      return result;
    } catch (e) {
      log(e.toString());
      return -1;
    }
  }

  Future<int> _getPingConnected() => _v2ray.getConnectedServerDelay();

  Future<int> _getPingToBaseServer() async {
    if (_configs.isEmpty) throw Exception("Base configuration not found");
    return _v2ray.getServerDelay(config: _configs.first.getFullConfiguration());
  }

  void dispose() {
    status.close();
  }
}
