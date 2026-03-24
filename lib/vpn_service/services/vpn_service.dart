import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:vpn/vpn_service/models/vpn_config.dart';
import 'package:vpn/vpn_service/services/test_config.dart';
import 'package:vpn/vpn_service/services/vpn_status.dart';

import 'ping_service.dart';
import 'vpn_channel_contract.dart';

/// Dart facade over the native VPN tunnel.
///
/// Usage:
/// ```dart
/// final vpn = VpnService.instance;
/// vpn.status.listen((s) => print(s));
///
/// final config = VpnConfig.fromUrl('vless://...');
/// await vpn.connect(config);
/// ...
/// await vpn.disconnect();
/// ```
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
  VpnConfig? _activeConfig;

  VpnConfig? get activeConfig => _activeConfig;

  // ── connect / disconnect ───────────────────────────────────────────────────

  /// Start the VPN tunnel for [config].
  ///
  /// Generates the full Xray/V2Ray JSON and passes it to the native side.
  /// Status transitions: disconnected → connecting (immediately), then
  /// the native side emits connected / disconnected via the event channel.
  Future<void> connect(VpnConfig config) async {
    if (status.value == VpnStatus.connected ||
        status.value == VpnStatus.connecting) {
      await disconnect();
    }

    _activeConfig = config;
    status.add(VpnStatus.connecting);

    try {
      final json = config.fullConfiguration;
      // final json = testConfig;

      await VpnChannelContract.invokeConnect(json);
    } catch (e, st) {
      _activeConfig = null;
      status.add(VpnStatus.error);
      // Re-throw so the UI layer can surface an error message.
      Error.throwWithStackTrace(VpnException('Failed to start tunnel: $e'), st);
    }
  }

  /// Stop the active tunnel.
  Future<void> disconnect() async {
    await VpnChannelContract.invokeDisconnect();
    _activeConfig = null;
    // Status will flip to disconnected once the native event arrives,
    // but we pre-set it so the UI is immediately responsive.
    status.add(VpnStatus.disconnected);
  }

  // ── parse ──────────────────────────────────────────────────────────────────

  /// Parse a share-link URL into a [VpnConfig].
  ///
  /// Throws [FormatException] on invalid / unsupported URLs.
  static VpnConfig parseUrl(String url) => VpnConfig.fromUrl(url);

  // ── ping ───────────────────────────────────────────────────────────────────

  /// TCP-handshake ping to the server in [config], in milliseconds.
  ///
  /// Does **not** require the VPN to be connected.
  /// Returns [defaultPingValue] on timeout / unreachable.
  static Future<int> ping(VpnConfig config) => PingService.ping(config);

  /// HTTP ping through the active tunnel's local SOCKS proxy, in milliseconds.
  ///
  /// Only meaningful while [status] == [VpnStatus.connected].
  /// Returns [defaultPingValue] if not connected or on error.
  static Future<int> pingConnected() async {
    if (instance.status.value != VpnStatus.connected) {
      return defaultPingValue;
    }
    return PingService.httpPingThroughProxy();
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
