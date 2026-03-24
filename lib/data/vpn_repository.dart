import 'dart:async';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vpn/vpn_service/vpn_service.dart';

class VpnRepository {
  final VpnService vpn = VpnService.instance;

  BehaviorSubject<VpnStatus> get status => vpn.status
    ..stream.listen((s) {
      _currentStatus = s;
    });
  VpnStatus _currentStatus = VpnStatus.disconnected;

  final _baseConfig = VpnService.parseUrl(dotenv.get('BASE_URL'));

  Future<void> connect() => vpn.connect(_baseConfig);

  Future<void> disconnect() => vpn.disconnect();

  Future<int> ping() async {
    log("ping requested, using $_currentStatus method to ping");
    try {
      final result = _currentStatus == VpnStatus.connected
          ? await _getPingConnected()
          : await _getPingToBaseServer();

      log("ping: $result ms");
      return result;
    } catch (e) {
      log(e.toString());
      return -1;
    }
  }

  Future<int> _getPingConnected() => VpnService.pingConnected();

  Future<int> _getPingToBaseServer() async {
    return VpnService.ping(_baseConfig);
  }

  void dispose() {
    status.close();
  }
}
