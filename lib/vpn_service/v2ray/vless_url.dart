

import '../models/vpn_config.dart';
import 'v2ray_url.dart';

/// Parses a VLESS share-link and produces a full V2Ray/Xray JSON config.
///
/// Format:
/// ```
/// vless://<uuid>@<host>:<port>?<params>#<remark>
/// ```
///
/// Common params:
/// - `type`        — transport: tcp | ws | grpc | h2 | kcp | quic
/// - `security`    — tls | reality | none
/// - `sni`         — server name indication
/// - `fp`          — TLS fingerprint (chrome | firefox | safari | …)
/// - `pbk`         — Reality public key
/// - `sid`         — Reality short ID
/// - `spx`         — Reality spider X
/// - `flow`        — xtls-rprx-vision | (empty)
/// - `encryption`  — always "none" for VLESS
/// - `alpn`        — comma-separated ALPN list
/// - `path`        — WebSocket / HTTP/2 path
/// - `host`        — HTTP host header override
/// - `headerType`  — tcp obfuscation header (http | none)
/// - `seed`        — KCP seed
/// - `quicSecurity`
/// - `key`         — QUIC key
/// - `mode`        — gRPC mode (gun | multi)
/// - `serviceName` — gRPC service name
class VlessUrl extends V2RayURL {
  VlessUrl({required super.url}) {
    _parse();
  }

  // ── internal parsed fields ────────────────────────────────────────────────

  late String _uuid;
  late String _address;
  late int _port;
  late String _remark;
  late String _flow;
  late String _network;
  late String _streamSecurity;
  late bool _allowInsecure;
  late String _sni;
  late String _fingerprint;
  late String? _alpn;
  late String? _publicKey;
  late String? _shortId;
  late String? _spiderX;
  late String? _headerType;
  late String? _host;
  late String? _path;
  late String? _seed;
  late String? _quicSecurity;
  late String? _quicKey;
  late String? _grpcMode;
  late String? _serviceName;

  // ── V2RayURL overrides ────────────────────────────────────────────────────

  @override
  String get address => _address;

  @override
  int get port => _port;

  @override
  String get network => _network;

  @override
  String get remark => _remark;

  @override
  bool get allowInsecure => _allowInsecure;

  // ── outbound ──────────────────────────────────────────────────────────────

  @override
  Map<String, dynamic> get outbound1 {
    // 1. Populate transport
    final derivedSni = populateTransportSettings(
      transport: _network,
      headerType: _headerType,
      host: _host,
      path: _path,
      seed: _seed,
      quicSecurity: _quicSecurity,
      key: _quicKey,
      mode: _grpcMode,
      serviceName: _serviceName,
    );

    // 2. Populate TLS / Reality
    populateTlsSettings(
      streamSecurity: _streamSecurity,
      allowInsecure: _allowInsecure,
      sni: _sni.isNotEmpty ? _sni : derivedSni,
      fingerprint: _fingerprint,
      alpns: _alpn,
      publicKey: _publicKey,
      shortId: _shortId,
      spiderX: _spiderX,
    );

    return {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': _address,
            'port': _port,
            'users': [
              {
                'id': _uuid,
                'encryption': 'none',
                'flow': _flow.isNotEmpty ? _flow : null,
                'level': level,
              },
            ],
          },
        ],
      },
      'streamSettings': removeNulls(Map.from(streamSetting)),
      'mux': null,
    };
  }

  // ── parsing ───────────────────────────────────────────────────────────────

  void _parse() {
    final uri = Uri.parse(url.trim());

    if (uri.scheme != 'vless') {
      throw FormatException('Expected vless:// scheme, got: ${uri.scheme}');
    }

    _uuid = uri.userInfo;
    if (_uuid.isEmpty) {
      throw const FormatException('VLESS URL is missing UUID in userInfo');
    }

    _address = uri.host;
    _port = uri.port > 0 ? uri.port : 443;
    _remark = Uri.decodeComponent(uri.fragment);

    final q = uri.queryParameters;

    _flow = q['flow'] ?? '';
    _network = q['type'] ?? 'tcp';
    _streamSecurity = q['security'] ?? 'none';
    _allowInsecure = q['allowInsecure'] == '1';
    _sni = q['sni'] ?? '';
    _fingerprint = q['fp'] ?? 'chrome';
    _alpn = q['alpn'];
    _publicKey = q['pbk'];
    _shortId = q['sid'];
    _spiderX = q['spx'];
    _headerType = q['headerType'];
    _host = q['host'];
    _path = q['path'];
    _seed = q['seed'];
    _quicSecurity = q['quicSecurity'];
    _quicKey = q['key'];
    _grpcMode = q['mode'];
    _serviceName = q['serviceName'];
  }

  // ── bidirectional conversion ──────────────────────────────────────────────

  /// Build a [VpnConfig] from this parsed URL.
  VpnConfig toConfig() => VpnConfig(
        address: _address,
        port: _port,
        uuid: _uuid,
        flow: _flow,
        network: _network,
        headerType: _headerType,
        host: _host,
        path: _path,
        seed: _seed,
        quicSecurity: _quicSecurity,
        quicKey: _quicKey,
        grpcMode: _grpcMode,
        serviceName: _serviceName,
        streamSecurity: _streamSecurity,
        allowInsecure: _allowInsecure,
        sni: _sni,
        fingerprint: _fingerprint,
        alpn: _alpn,
        publicKey: _publicKey ?? '',
        shortId: _shortId ?? '',
        spiderX: _spiderX ?? '',
        remark: _remark,
      );

  /// Re-create a [VlessUrl] instance from a [VpnConfig] (for JSON generation).
  factory VlessUrl.fromConfig(VpnConfig c) {
    final params = <String, String>{
      'type': c.network,
      'security': c.streamSecurity,
      if (c.flow.isNotEmpty) 'flow': c.flow,
      if (c.sni.isNotEmpty) 'sni': c.sni,
      if (c.fingerprint.isNotEmpty) 'fp': c.fingerprint,
      if (c.publicKey.isNotEmpty) 'pbk': c.publicKey,
      if (c.shortId.isNotEmpty) 'sid': c.shortId,
      if (c.spiderX.isNotEmpty) 'spx': c.spiderX,
      if (c.alpn != null) 'alpn': c.alpn!,
      if (c.headerType != null) 'headerType': c.headerType!,
      if (c.host != null) 'host': c.host!,
      if (c.path != null) 'path': c.path!,
      if (c.seed != null) 'seed': c.seed!,
      if (c.quicSecurity != null) 'quicSecurity': c.quicSecurity!,
      if (c.quicKey != null) 'key': c.quicKey!,
      if (c.grpcMode != null) 'mode': c.grpcMode!,
      if (c.serviceName != null) 'serviceName': c.serviceName!,
      if (c.allowInsecure) 'allowInsecure': '1',
    };

    final uri = Uri(
      scheme: 'vless',
      userInfo: c.uuid,
      host: c.address,
      port: c.port,
      queryParameters: params,
      fragment: c.remark,
    );

    return VlessUrl(url: uri.toString());
  }
}
