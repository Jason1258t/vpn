import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:rxdart/rxdart.dart';

enum VpnStatus { disconnected, connection, connected }

// Предполагаемая константа
const String baseSubscriptionUrl =
    'vless://ad87aeca-bec5-48b4-bfe2-50d37d15f5e5@89.22.226.178:8443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=FIwSyEwgTqSgMWMlN0kP9Aw5V6C2_k4-kvNSDa7B9kQ&sid=83cabdf6e9d5aef4&type=tcp#RealityVPN';

class VpnRepository {
  late final FlutterV2ray _v2ray;
  final BehaviorSubject<VpnStatus> status;

  // Список распарсенных конфигураций (VLESS, VMess, Trojan и т.д.)
  List<String> _configs = [
    FlutterV2ray.parseFromURL(baseSubscriptionUrl).getFullConfiguration(),
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

  /// Подключение по индексу, имитируя старое поведение
  Future<void> connect({int serverIndex = 0}) async {
    if (_configs.isEmpty || serverIndex >= _configs.length) {
      log('configs is empty');
      return;
    }

    final config = _configs[serverIndex];
    if (await _v2ray.requestPermission()) {
      await _v2ray.startV2Ray(
        remark: 'Server $serverIndex',
        config: config,
        proxyOnly: false,
      );
    }
  }

  Future<void> disconnect() async {
    await _v2ray.stopV2Ray();
  }

  /// Пинг конкретного сервера из подписки
  Future<int> ping({int serverIndex = 0}) async {
    if ((await status.last) == VpnStatus.connected) {
      return _v2ray.getConnectedServerDelay();
    }

    if (_configs.isEmpty || serverIndex >= _configs.length) return -1;

    return _v2ray.getServerDelay(config: _configs[serverIndex]);
  }

  void dispose() {
    status.close();
  }
}
