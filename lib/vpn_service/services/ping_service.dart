import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Результат замера задержки
class PingResult {
  final int latency; // в мс, -1 если ошибка
  final String? error;
  final String target;

  bool get isSuccess => latency >= 0;

  PingResult({required this.latency, required this.target, this.error});

  @override
  String toString() =>
      isSuccess ? '$target: ${latency}ms' : '$target failed: $error';
}

class PingService {
  // Константы для настроек по умолчанию
  static const int _defaultTimeout = 3; // секунды
  static const String _pingHost = 'google.com';

  /// 1. Основной метод: Пинг до конкретного прокси-сервера (TCP Handshake)
  /// Принимает [host] и [port]. Это самый быстрый способ проверить доступность ноды.
  static Future<PingResult> tcpPing({
    required String host,
    required int port,
    int timeoutSeconds = _defaultTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: timeoutSeconds),
      );

      stopwatch.stop();
      socket.destroy();

      return PingResult(
        latency: stopwatch.elapsedMilliseconds,
        target: '$host:$port',
      );
    } catch (e) {
      return PingResult(
        latency: -1,
        target: '$host:$port',
        error: e.toString(),
      );
    }
  }

  /// 2. Метод для проверки "качества интернета" через уже поднятое VPN соединение.
  /// Делает полноценный HTTP запрос, чтобы убедиться, что трафик реально ходит.
  static Future<int> pingHost({
    String host = _pingHost,
    int timeoutSeconds = _defaultTimeout,
  }) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = Duration(seconds: timeoutSeconds);
      final stopwatch = Stopwatch()..start();

      // Используем HEAD запрос - он максимально легкий
      final request = await client.headUrl(Uri.parse('https://$host'));
      final response = await request.close();

      stopwatch.stop();

      if (response.statusCode < 400) {
        return stopwatch.elapsedMilliseconds;
      }
      return -1;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return -1;
    }
  }

  /// 3. Парсинг конфига и пинг (Helper)
  /// Если на вход прилетает ссылка или сложная строка, выдергиваем host:port и пингуем.
  static Future<int> pingConfig(String config) async {
    try {
      // Очень упрощенный парсинг для примера.
      // В идеале тут должен быть твой парсер VLESS/VMESS ссылок.
      if (config.startsWith('vless://') || config.startsWith('vmess://')) {
        final uri = Uri.parse(config.replaceFirst('vmess://', 'http://'));
        return (await tcpPing(host: uri.host, port: uri.port)).latency;
      }

      // Если это JSON или что-то еще - логика парсинга тут
      return -1;
    } catch (_) {
      return -1;
    }
  }
}
