import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vpn/data/protocol_manager.dart';
import 'vpn_session.dart';
import '../vpn_service/vpn_status.dart';
import 'cache_manager.dart';
import 'vpn_repository.dart';

part 'vpn_provider.g.dart';

@riverpod
class VpnController extends _$VpnController {
  Timer? _pingTimer;

  late final VpnRepository _repo;
  late final ProtocolManager _protocolManager;

  @override
  VpnSessionStatus build() {
    _repo = ref.watch(vpnRepositoryProvider);
    _protocolManager = ref.watch(protocolManagerProvider);

    _initAsync();
    return VpnSessionStatus(protocol: ProtocolManager.defaultProtocol);
  }

  _initAsync() async {
    final protocol = await _protocolManager.getProtocol();
    _repo.setConfigUrl(await _protocolManager.currentConnectUrl);

    final ping = await _repo.ping();
    final VpnStatus status;
    final cacheManager = ref.read(cacheManagerProvider);
    DateTime? cachedSession = await cacheManager.getStartTime();

    if (cachedSession != null) {
      if (await _repo.isConnected()) {
        status = VpnStatus.connected;
      } else {
        status = VpnStatus.disconnected;
        cachedSession = null;
        cacheManager.clearStartTime();
      }
    } else {
      status = VpnStatus.disconnected;
    }

    state = VpnSessionStatus(
      ping: ping,
      status: status,
      sessionStartTime: cachedSession,
      protocol: protocol,
    );

    _repo.status.stream.listen(_handleStatusChange);
    _initializePingChecker();
  }

  _handleStatusChange(VpnStatus s) async {
    if (s == state.status) return;
    final cacheManager = ref.read(cacheManagerProvider);
    if (s == VpnStatus.connected) {
      cacheManager.saveStartTime(DateTime.now());
      state = state.copyWith(status: s, sessionStartTime: DateTime.now());
    } else if (s == VpnStatus.disconnected) {
      cacheManager.clearStartTime();
      state = state.copyWith(status: s, sessionStartTime: null);
    } else {
      state = state.copyWith(status: s);
    }
  }

  _initializePingChecker() {
    _pingTimer = Timer.periodic(Duration(seconds: 5), (t) => updatePing());
    ref.onDispose(() {
      _pingTimer?.cancel();
    });
  }

  Future<void> toggleConnection() async {
    state.status == VpnStatus.disconnected ? _repo.connect() : _repo.disconnect();
  }

  Future<void> toggleProtocol() async {
    if (state.status != VpnStatus.disconnected) await _repo.disconnect();
    final protocol = await _protocolManager.getProtocol();

    final newProtocol = protocol == AvailableProtocols.vlessReality
        ? AvailableProtocols.vlessXHttpTLS
        : AvailableProtocols.vlessReality;

    await _protocolManager.setProtocol(newProtocol);
    _repo.setConfigUrl(await _protocolManager.currentConnectUrl);

    state = state.copyWith(
      protocol: newProtocol,
      status: VpnStatus.disconnected,
    );
  }

  Future<void> updatePing() async {
    final ping = await _repo.ping();
    state = state.copyWith(ping: ping);
  }
}
