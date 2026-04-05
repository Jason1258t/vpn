import 'dart:async';
import 'dart:developer';

import 'package:rxdart/rxdart.dart';
import 'package:vpn/vpn_service/services/vpn_status.dart';

import 'ping_service.dart';
import 'vpn_channel_contract.dart';

/// Dart facade over the native VPN tunnel.
class VpnService {
  VpnService._() {
    _listenToNativeEvents();
  }

  static final VpnService instance = VpnService._();

  // ── public state ───────────────────────────────────────────────────────────

  /// Reactive stream of tunnel status. Seeded with [VpnStatus.disconnected].
  final BehaviorSubject<VpnStatus> status = BehaviorSubject.seeded(
    VpnStatus.disconnected,
  );

  /// The config currently in use (null if not connected).
  String? _activeConfig;

  String? get activeConfig => _activeConfig;

  // ── connect / disconnect ───────────────────────────────────────────────────

  /// Start the VPN tunnel for [url].
  ///
  /// Status transitions: disconnected → connecting (immediately), then
  /// the native side emits connected / disconnected via the event channel.
  Future<void> connectBuUrl(String url) async {
    await disconnect();
    status.add(VpnStatus.connecting);

    try {
      await VpnChannelContract.invokeConnect(url);
      _activeConfig = url;
    } catch (e, st) {
      _activeConfig = null;
      status.add(VpnStatus.error);
      // Re-throw so the UI layer can surface an error message.
      Error.throwWithStackTrace(VpnException('Failed to start tunnel: $e'), st);
    }
  }

  /// Stop the active tunnel.
  Future<void> disconnect() async {
    if (status.value == VpnStatus.disconnected) return;
    await VpnChannelContract.invokeDisconnect();
    _activeConfig = null;
  }

  Future<bool> isServiceRunning() async {
    try {
      return await VpnChannelContract.methodChannel.invokeMethod('isActive');
    } catch (_) {
      return false;
    }
  }

  // ── ping ───────────────────────────────────────────────────────────────────

  /// TCP-handshake ping to the server in [config], in milliseconds.
  ///®
  /// Does **not** require the VPN to be connected.
  /// Returns [defaultPingValue] on timeout / unreachable.
  static Future<int> ping(String config) async {
    try {
      final res = PingService.pingConfig(config);
      return res;
    } catch (e) {
      log(e.toString());
      return defaultPingValue;
    }
  }

  /// HTTP ping through the active tunnel's local SOCKS proxy, in milliseconds.
  ///
  /// Only meaningful while [status] == [VpnStatus.connected].
  /// Returns [defaultPingValue] if not connected or on error.
  static Future<int> pingConnected() async {
    try {
      final res = await PingService.pingHost();
      return res;
    } catch (e) {
      log(e.toString());
      return defaultPingValue;
    }
  }

  // ── native event bridge ────────────────────────────────────────────────────

  StreamSubscription<dynamic>? _eventSubscription;

  void _listenToNativeEvents() {
    _eventSubscription = VpnChannelContract.eventChannel
        .receiveBroadcastStream()
        .listen(_onNativeEvent, onError: _onNativeError);
  }

  void _onNativeEvent(dynamic event) {
    final newStatus = switch (event as String?) {
      VpnChannelContract.eventConnected => VpnStatus.connected,
      VpnChannelContract.eventConnecting => VpnStatus.connecting,
      VpnChannelContract.eventError => VpnStatus.error,
      _ => VpnStatus.disconnected,
    };

    if (newStatus == VpnStatus.disconnected) {
      _activeConfig = null;
    }

    status.add(newStatus);
  }

  void _onNativeError(Object error) {
    _activeConfig = null;
    status.add(VpnStatus.disconnected);
  }

  // ── dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await status.close();
  }
}

// ── exceptions ─────────────────────────────────────────────────────────────

class VpnException implements Exception {
  const VpnException(this.message);

  final String message;

  @override
  String toString() => 'VpnException: $message';
}
