import 'dart:convert';

class XrayConfigService {
  static const int socksPort = 10808;

  static String? vlessToXrayJson(
    String url, {
    bool enableSplitTunneling = true,
  }) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'vless') return null;

      final params = uri.queryParameters;
      final transport = params['type'] ?? 'tcp';
      final security = params['security'] ?? 'none';

      // 1. Формируем streamSettings динамически
      final Map<String, dynamic> streamSettings = {
        "network": transport,
        "security": security,
      };

      // Настройка транспорта (TCP, xHTTP и т.д.)
      if (transport == 'xhttp') {
        streamSettings['xhttpSettings'] = {
          "path": params['path'] ?? "/",
          "mode": params['mode'] ?? "auto",
          "host": params['host'] ?? uri.host,
        };
      }

      // Настройка безопасности (Reality или TLS)
      if (security == 'reality') {
        streamSettings['realitySettings'] = {
          "show": false,
          "fingerprint": params['fp'] ?? "chrome",
          "serverName": params['sni'] ?? "",
          "publicKey": params['pbk'] ?? "",
          "shortId": params['sid'] ?? "",
          "spiderX": "/",
        };
      } else if (security == 'tls') {
        final allowInsecureStr = params['allowInsecure']?.toLowerCase();
        final bool allowInsecure =
            allowInsecureStr == 'true' || allowInsecureStr == '1';

        streamSettings['tlsSettings'] = {
          "serverName": params['sni'] ?? "",
          "fingerprint": params['fp'] ?? "chrome",
          "allowInsecure": allowInsecure,
        };
      }

      final rules = [];

      if (enableSplitTunneling) {
        // Правило для российских доменов (geosite + регулярки)
        rules.add({
          "domain": [
            "geosite:category-ru",
            r"regexp:.*\.ru$",
            r"regexp:.*\.рф$",
            r"regexp:.*\.su$",
            r"regexp:.*\.moscow$",
            r"regexp:.*\.msk\.ru$",
            r"regexp:.*\.spb\.ru$",
            r"regexp:.*\.tatar$",
            r"regexp:.*\.дети$",
            r"regexp:.*\.католик$",
            r"regexp:.*\.онлайн$",
            r"regexp:.*\.сайт$",
          ],
          "outboundTag": "direct",
        });

        // Правило для российских IP-адресов
        rules.add({
          "ip": ["geoip:ru"],
          "outboundTag": "direct",
        });
      }

      // 2. Сборка полного конфига
      final config = {
        "log": {"loglevel": "warning"},
        "routing": {"domainStrategy": "IPIfNonMatch", "rules": rules},
        "outbounds": [
          {
            "protocol": "vless",
            "tag": "proxy",
            "settings": {
              "vnext": [
                {
                  "address": uri.host,
                  "port": uri.port,
                  "users": [
                    {
                      "id": uri.userInfo,
                      "flow": (transport == 'tcp' && security == 'reality')
                          ? (params['flow'] ?? "xtls-rprx-vision")
                          : "", // Flow нужен только для Reality + TCP
                      "encryption": "none",
                    },
                  ],
                },
              ],
            },
            "streamSettings": streamSettings,
          },
          {"tag": "direct", "protocol": "freedom"},
          {"tag": "block", "protocol": "blackhole"},
        ],
      };

      return jsonEncode(config);
    } catch (e) {
      return null;
    }
  }
}
