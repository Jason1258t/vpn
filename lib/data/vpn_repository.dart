import 'dart:async';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vpn/vpn_service/vpn_service.dart';

class VpnRepository {
  final VpnService _vpn = VpnService.instance;

  BehaviorSubject<VpnStatus> get status => _vpn.status
    ..stream.listen((s) {
      _currentStatus = s;
    });
  VpnStatus _currentStatus = VpnStatus.disconnected;

  static final _baseConfigUrl = dotenv.get('BASE_URL');

  Future<void> connect() => _vpn.connectBuUrl(_baseConfigUrl);

  Future<void> disconnect() => _vpn.disconnect();

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

  Future<int> _getPingToBaseServer() async {
    return VpnService.ping(_baseConfigUrl);
  }

  void dispose() {
    status.close();
  }
}
