import 'dart:async';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vpn/data/cache_manager.dart';
import 'package:vpn/vpn_service/vpn_service.dart';

class VpnSession {
  DateTime startTime;
  DateTime? endTime;

  VpnSession(this.startTime, {this.endTime});
}

class VpnRepository {
  final VpnService _vpn = VpnService.instance;

  BehaviorSubject<VpnStatus> get status => _vpn.status
    ..stream.listen((s) {
      _currentStatus = s;
    });
  VpnStatus _currentStatus = VpnStatus.disconnected;

  static final _baseConfigUrl = dotenv.get('BASE_URL');

  Future<void> connect() async {
    await _vpn.connectBuUrl(_baseConfigUrl);
  }

  Future<void> disconnect() async {
    await _vpn.disconnect();
  }

  Future<bool> isConnected() async {
    final res = await _vpn.isServiceRunning();
    if (res && status.value != VpnStatus.connected) status.add(VpnStatus.connected);
    return res;
  }

  Future<int> ping() async {
    try {
      final result = _currentStatus == VpnStatus.connected
          ? await _getPingConnected()
          : await _getPingToBaseServer();

      return result;
    } catch (e) {
      log(e.toString());
      return -1;
    }
  }

  Future<int> _getPingConnected() => VpnService.pingConnected();

  Future<int> _getPingToBaseServer() => VpnService.ping(_baseConfigUrl);

  void dispose() {
    status.close();
  }
}
