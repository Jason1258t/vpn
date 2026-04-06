import 'dart:async';
import 'dart:developer';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vpn/vpn_service/vpn_service.dart';

part 'vpn_repository.g.dart';

@riverpod
VpnRepository vpnRepository(Ref ref) {
  return VpnRepository();
}

class VpnRepository {
  final VpnService _vpn = VpnService.instance;

  late final BehaviorSubject<VpnStatus> _statusController;

  VpnRepository() {
    _statusController = _vpn.status;
    _statusController.stream.listen((s) {
      _currentStatus = s;
    });
  }

  BehaviorSubject<VpnStatus> get status => _statusController;

  VpnStatus _currentStatus = VpnStatus.disconnected;

  String? _currentConfigUrl;

  void setConfigUrl(String url) {
    _currentConfigUrl = url;
  }

  Future<void> connect() async {
    await _vpn.connectBuUrl(_currentConfigUrl!);
  }

  Future<void> disconnect() async {
    await _vpn.disconnect();
  }

  Future<bool> isConnected() async {
    final res = await _vpn.isServiceRunning();
    if (res && status.value != VpnStatus.connected) {
      status.add(VpnStatus.connected);
    }
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

  Future<int> _getPingToBaseServer() async {
    if (_currentConfigUrl == null) return -1;
    return await VpnService.ping(_currentConfigUrl!);
  }

  void dispose() {
    status.close();
  }
}
