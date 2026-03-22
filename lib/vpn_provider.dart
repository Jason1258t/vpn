import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'vpn_repository.dart';

part 'vpn_provider.g.dart';

@riverpod
VpnRepository vpnRepository(ref) {
  return VpnRepository();
}

@riverpod
Stream<VpnStatus> vpnStatus(ref) {
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
    ref.onDispose(() {
      _timer?.cancel();
    });
    return 0;
  }

  _initializePingChecker() {
    _timer = Timer.periodic(Duration(seconds: 5), (t) => updatePing());
  }

  Future<void> toggleConnection() async {
    final repo = ref.read(vpnRepositoryProvider);
    final status = ref.read(vpnStatusProvider).value;

    if (status == VpnStatus.connected) {
      repo.disconnect();
    } else {
      repo.connect();
      await updatePing();
    }
  }

  Future<void> updatePing() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(vpnRepositoryProvider).ping(),
    );
  }
}
