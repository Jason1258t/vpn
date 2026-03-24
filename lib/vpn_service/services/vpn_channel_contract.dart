import 'package:flutter/services.dart';

/// Method-channel names agreed upon with the native (Android / iOS) host.
///
/// The native side is responsible for:
///  - embedding the Xray-core or V2Ray-core library
///  - starting / stopping the VPN tunnel (VpnService on Android, NEPacketTunnel on iOS)
///  - forwarding status events back via [eventChannel]
abstract class VpnChannelContract {
  // ── channels ───────────────────────────────────────────────────────────────

  static const MethodChannel methodChannel =
      MethodChannel('com.zxc.vpn/vpn_service');

  static const EventChannel eventChannel =
      EventChannel('com.zxc.vpn/vpn_status');

  // ── method names ───────────────────────────────────────────────────────────

  static const String methodConnect = 'connect';
  static const String methodDisconnect = 'disconnect';

  // ── argument keys ──────────────────────────────────────────────────────────

  /// Full V2Ray JSON configuration string.
  static const String argConfig = 'config';

  // ── status event values ────────────────────────────────────────────────────

  /// Native side sends one of these strings on the event channel.
  static const String eventDisconnected = 'disconnected';
  static const String eventError = 'error';
  static const String eventConnecting = 'connecting';
  static const String eventConnected = 'connected';

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Call [methodConnect] with a serialised configuration JSON.
  static Future<void> invokeConnect(String configJson) async {
    await methodChannel.invokeMethod<void>(
      methodConnect,
      {argConfig: configJson},
    );
  }

  static Future<void> invokeDisconnect() async {
    await methodChannel.invokeMethod<void>(methodDisconnect);
  }
}
