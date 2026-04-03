import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vpn/vpn_service/services/test_config.dart';

import 'vpn_status.dart';
import '../models/vpn_config.dart';

/// Ping helpers.
///
/// На Android используется нативный [LibXray.ping] через MethodChannel —
/// он точнее TCP-сокета, потому что измеряет реальный RTT через Xray-стек.
/// На iOS (и как fallback) — TCP handshake напрямую до сервера.
class PingService {
  PingService._();

  static const _channel = MethodChannel('com.zxc.vpn/vpn_service');
  static const _tcpTimeout = Duration(seconds: 5);

  // ── public API ─────────────────────────────────────────────────────────────

  /// Пинг до сервера [config] в миллисекундах.
  ///
  /// Android: делегирует в LibXray.ping — встроенный RTT-замер.
  /// iOS / desktop: TCP handshake через Socket.connect.
  /// Возвращает [defaultPingValue] при таймауте или недоступности.
  static Future<int> ping(VpnConfig config) async {
    if (Platform.isAndroid) {
      return _nativePing(config);
    }
    return tcpPing(config);
  }

  /// HTTP-пинг через активный SOCKS5-прокси туннеля (127.0.0.1:1080).
  /// Актуален только когда VPN подключён.
  static Future<int> httpPingThroughProxy({
    String proxyHost = '127.0.0.1',
    int proxyPort = 1080,
  }) async {
    final sw = Stopwatch()..start();
    HttpClient? client;
    try {
      client = HttpClient()..findProxy = (_) => 'SOCKS5 $proxyHost:$proxyPort';

      client.connectionTimeout = const Duration(seconds: 8);

      final req = await client
          .getUrl(Uri.parse('http://cp.cloudflare.com/'))
          .timeout(const Duration(seconds: 8));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.first.timeout(const Duration(seconds: 8));

      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return defaultPingValue;
    } finally {
      client?.close(force: true);
    }
  }

  // ── Android native ping via LibXray ───────────────────────────────────────

  /// LibXray.ping принимает JSON вида:
  /// {"url":"https://host:port","timeout":5000}
  /// и возвращает RTT в мс или ошибку.
  static Future<int> _nativePing(VpnConfig config) async {
    try {
      final result = await _channel.invokeMethod<String>('ping', {
        'configJson': config.fullConfiguration
        // 'configJson': testConfig
      });
      return int.tryParse(result ?? '') ?? defaultPingValue;
    } catch (_) {
      return defaultPingValue;
    }
  }

  // ── TCP fallback ──────────────────────────────────────────────────────────

  static Future<int> tcpPing(VpnConfig config) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        config.address,
        config.port,
        timeout: _tcpTimeout,
      );
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return defaultPingValue;
    } finally {
      socket?.destroy();
    }
  }
}
