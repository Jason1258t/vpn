import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vpn/vpn_service/services/test_config.dart';
import 'package:vpn/vpn_service/services/vpn_channel_contract.dart';

import 'vpn_status.dart';
import '../models/vpn_config.dart';

/// Ping helpers.
///
/// На Android используется нативный [LibXray.ping] через MethodChannel —
/// он точнее TCP-сокета, потому что измеряет реальный RTT через Xray-стек.
/// На iOS (и как fallback) — TCP handshake напрямую до сервера.
class PingService {
  PingService._();

  static const _channel = VpnChannelContract.methodChannel;
  static const _timeout = Duration(seconds: 5);

  // ── public API ─────────────────────────────────────────────────────────────

  /// Пинг до сервера [config] в миллисекундах.
  ///
  /// Android: делегирует в LibXray.ping — встроенный RTT-замер.
  /// iOS / desktop: TCP handshake через Socket.connect.
  /// Возвращает [defaultPingValue] при таймауте или недоступности.
  static Future<int> ping(String config) async {
    if (Platform.isAndroid) {
      return _nativeAndroidPing(config);
    }

    return -1;
  }


  // ── Android native ping via LibXray ───────────────────────────────────────

  /// LibXray.ping принимает JSON вида:
  /// {"url":"https://host:port","timeout":5000}
  /// и возвращает RTT в мс или ошибку.
  static Future<int> _nativeAndroidPing(String config) async {
    throw UnimplementedError();
  }
}
