import 'dart:convert';

/// Abstract base for protocol-specific V2Ray URL parsers.
abstract class V2RayURL {
  V2RayURL({required this.url});

  final String url;

  bool get allowInsecure => true;
  String get security => 'auto';
  int get level => 8;
  int get port => 443;
  String get network => 'tcp';
  String get address => '';
  String get remark => '';

  // ── inbound (local SOCKS proxy — только для ping) ────────────────────────

  Map<String, dynamic> inbound = {
    'tag': 'proxy_in',
    'port': 10808,
    'protocol': 'socks',
    'listen': '127.0.0.1',
    'settings': {
      'auth': 'noauth',
      'udp': true,
      'userLevel': 8,
    },
    'sniffing': {
      'enabled': true,
      'destOverride': ['http', 'tls', 'quic'],
    },
  };

  // ── inbound (TUN — для реального VPN трафика) ────────────────────────────
  // fd передаётся ядру через env XRAY_TUN_FD из XrayVpnService.kt

  Map<String, dynamic> tunInbound = {
    'tag': 'tun-in',
    'protocol': 'tun',
    'settings': {
      'network': 'tcp,udp',
    },
    'sniffing': {
      'enabled': true,
      'destOverride': ['http', 'tls', 'quic'],
    },
  };

  Map<String, dynamic> log = {
    'access': '',
    'error': '',
    'loglevel': 'error',
    'dnsLog': false,
  };

  // ── must be implemented ───────────────────────────────────────────────────

  Map<String, dynamic> get outbound1;

  // ── fixed outbounds ───────────────────────────────────────────────────────

  Map<String, dynamic> outbound2 = {
    'tag': 'direct',
    'protocol': 'freedom',
    'settings': {'domainStrategy': 'UseIp'},
  };

  Map<String, dynamic> outbound3 = {
    'tag': 'blackhole',
    'protocol': 'blackhole',
    'settings': {},
  };

  Map<String, dynamic> dns = {
    'servers': ['8.8.8.8', '8.8.4.4'],
  };

  Map<String, dynamic> routing = {
    'domainStrategy': 'AsIs',
    'rules': [
      {
        'type': 'field',
        'inboundTag': ['tun-in', 'proxy_in'], // оба источника → proxy outbound
        'outboundTag': 'proxy',
        'network': 'tcp,udp',
      }
    ],
  };

  Map<String, dynamic> get fullConfiguration => {
    'log': log,
    'inbounds': [tunInbound, inbound], // tun первым
    'outbounds': [outbound1, outbound2, outbound3],
    'dns': dns,
    'routing': routing,
  };

  /// Returns pretty-printed V2Ray JSON.
  String getFullConfiguration({int indent = 2}) {
    return JsonEncoder.withIndent(' ' * indent)
        .convert(removeNulls(Map.from(fullConfiguration)));
  }

  // ── stream settings helpers ───────────────────────────────────────────────

  late Map<String, dynamic> streamSetting = {
    'network': network,
    'security': '',
    'tcpSettings': null,
    'kcpSettings': null,
    'wsSettings': null,
    'httpSettings': null,
    'tlsSettings': null,
    'quicSettings': null,
    'realitySettings': null,
    'grpcSettings': null,
    'sockopt': null,
  };

  /// Populates transport-layer settings and returns the derived SNI value.
  String populateTransportSettings({
    required String transport,
    required String? headerType,
    required String? host,
    required String? path,
    required String? seed,
    required String? quicSecurity,
    required String? key,
    required String? mode,
    required String? serviceName,
  }) {
    String sni = '';
    streamSetting['network'] = transport;

    switch (transport) {
      case 'tcp':
        streamSetting['tcpSettings'] = {
          'header': {'type': 'none', 'request': null},
          'acceptProxyProtocol': null,
        };
        if (headerType == 'http' && (host != '' || path != '')) {
          streamSetting['tcpSettings']['header']['type'] = 'http';
          streamSetting['tcpSettings']['header']['request'] = {
            'path': path == null ? ['/'] : path.split(','),
            'headers': {
              'Host': host == null ? [] : host.split(','),
              'User-Agent': [
                'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/53.0.2785.143 Safari/537.36',
              ],
              'Accept-Encoding': ['gzip, deflate'],
              'Connection': ['keep-alive'],
              'Pragma': 'no-cache',
            },
            'version': '1.1',
            'method': 'GET',
          };
          final hosts = streamSetting['tcpSettings']['header']['request']
          ['headers']['Host'] as List;
          if (hosts.isNotEmpty) sni = hosts.first as String;
        } else {
          streamSetting['tcpSettings']['header']['type'] = 'none';
          sni = (host != null && host.isNotEmpty) ? host : '';
        }

      case 'kcp':
        streamSetting['kcpSettings'] = {
          'mtu': 1350,
          'tti': 50,
          'uplinkCapacity': 12,
          'downlinkCapacity': 100,
          'congestion': false,
          'readBufferSize': 1,
          'writeBufferSize': 1,
          'header': {'type': headerType ?? 'none'},
          'seed': (seed == null || seed.isEmpty) ? null : seed,
        };

      case 'ws':
        streamSetting['wsSettings'] = {
          'path': path ?? '/',
          'headers': {'Host': host ?? ''},
        };
        sni = host ?? '';

      case 'h2':
      case 'http':
        streamSetting['network'] = 'h2';
        streamSetting['h2Settings'] = {
          'host': host?.split(',') ?? [],
          'path': path ?? '/',
        };
        final h2Hosts = streamSetting['h2Settings']['host'] as List;
        if (h2Hosts.isNotEmpty) sni = h2Hosts.first as String;

      case 'quic':
        streamSetting['quicSettings'] = {
          'security': quicSecurity ?? 'none',
          'key': key ?? '',
          'header': {'type': headerType ?? 'none'},
        };

      case 'grpc':
        streamSetting['grpcSettings'] = {
          'serviceName': serviceName ?? '',
          'multiMode': mode == 'multi',
        };
        sni = host ?? '';
    }

    return sni;
  }

  void populateTlsSettings({
    required String? streamSecurity,
    required bool allowInsecure,
    required String? sni,
    required String? fingerprint,
    required String? alpns,
    required String? publicKey,
    required String? shortId,
    required String? spiderX,
  }) {
    streamSetting['security'] = streamSecurity;

    final tlsSetting = <String, dynamic>{
      'allowInsecure': allowInsecure,
      'serverName': sni,
      'alpn': (alpns == null || alpns.isEmpty) ? null : alpns.split(','),
      'fingerprint': fingerprint,
      'show': false,
      'publicKey': publicKey,
      'shortId': shortId,
      'spiderX': spiderX,
    };

    if (streamSecurity == 'tls') {
      streamSetting['realitySettings'] = null;
      streamSetting['tlsSettings'] = tlsSetting;
    } else if (streamSecurity == 'reality') {
      streamSetting['tlsSettings'] = null;
      streamSetting['realitySettings'] = tlsSetting;
    }
  }

  // ── utility ───────────────────────────────────────────────────────────────

  dynamic removeNulls(dynamic value) {
    if (value is Map) {
      final result = <dynamic, dynamic>{};
      value.forEach((k, v) {
        final cleaned = removeNulls(v);
        if (cleaned != null) result[k] = cleaned;
      });
      return result.isNotEmpty ? result : null;
    }
    if (value is List) {
      final result = value.map(removeNulls).whereType<Object>().toList();
      return result.isNotEmpty ? result : null;
    }
    return value;
  }
}