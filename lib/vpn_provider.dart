import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vpn/vpn_status.dart';
import 'vpn_repository.dart';

part 'vpn_provider.g.dart';

@riverpod
VpnRepository vpnRepository(Ref ref) {
  return VpnRepository();
}

@riverpod
Stream<VpnStatus> vpnStatus(Ref ref) {
  final repo = ref.watch(vpnRepositoryProvider);
  return repo.status.stream;
}

@riverpod
class VpnController extends _$VpnController {
  Timer? _timer;

  @override
  FutureOr<int> build() {
    updatePing();
    _initializePingChecker();
    return defaultPingValue;
  }

  _initializePingChecker() {
    _timer = Timer.periodic(Duration(seconds: 5), (t) => updatePing());
    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  Future<void> toggleConnection() async {
    final repo = ref.read(vpnRepositoryProvider);
    final status = ref.read(vpnStatusProvider).value;

    status == VpnStatus.connected ? repo.disconnect() : repo.connect();
  }

  Future<void> updatePing() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(vpnRepositoryProvider).ping(),
    );
  }
}
