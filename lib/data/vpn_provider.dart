import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vpn/data/protocol_manager.dart';
import 'vpn_session.dart';
import '../vpn_service/services/vpn_status.dart';
import 'cache_manager.dart';
import 'vpn_repository.dart';

part 'vpn_provider.g.dart';


@Riverpod(keepAlive: true)
VpnRepository vpnRepository(Ref ref) {
  return VpnRepository();
}

@riverpod
Stream<VpnStatus> vpnStatus(Ref ref) {
  final repo = ref.read(vpnRepositoryProvider);
  return repo.status.stream;
}

@riverpod
class VpnController extends _$VpnController {
  Timer? _pingTimer;

  @override
  VpnSessionStatus build() {
    _initAsync();
    return VpnSessionStatus(protocol: ProtocolManager.defaultProtocol);
  }

  _initAsync() async {
    final repo = ref.read(vpnRepositoryProvider);
    final protocolManager = ref.read(protocolManagerProvider);

    final protocol = await protocolManager.getProtocol();
    repo.setConfigUrl(await protocolManager.currentConnectUrl);

    final ping = await repo.ping();
    final VpnStatus status;
    final cacheManager = ref.read(cacheManagerProvider);
    DateTime? cachedSession = await cacheManager.getStartTime();

    if (cachedSession != null) {
      if (await repo.isConnected()) {
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

    ref.read(vpnRepositoryProvider).status.stream.listen(_handleStatusChange);
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
    final repo = ref.read(vpnRepositoryProvider);
    state.status == VpnStatus.disconnected ? repo.connect() : repo.disconnect();
  }

  Future<void> toggleProtocol() async {
    final repo = ref.read(vpnRepositoryProvider);
    if (state.status != VpnStatus.disconnected) await repo.disconnect();
    final protocolManager = ref.read(protocolManagerProvider);
    final protocol = await protocolManager.getProtocol();

    final newProtocol = protocol == AvailableProtocols.vlessReality
        ? AvailableProtocols.vlessXHttpTLS
        : AvailableProtocols.vlessReality;

    await protocolManager.setProtocol(newProtocol);
    repo.setConfigUrl(await protocolManager.currentConnectUrl);

    state = state.copyWith(
      protocol: newProtocol,
      status: VpnStatus.disconnected,
    );
  }

  Future<void> updatePing() async {
    final ping = await ref.read(vpnRepositoryProvider).ping();
    state = state.copyWith(ping: ping);
  }
}
