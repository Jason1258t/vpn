import '../v2ray/vless_url.dart';

/// Immutable snapshot of a single VPN server configuration.
///
/// Constructed either via [VpnConfig.fromUrl] (VLESS share-link) or
/// directly through the named constructor for manual entries.
class VpnConfig {
  const VpnConfig({
    required this.address,
    required this.port,
    required this.uuid,
    this.flow = 'xtls-rprx-vision',
    // transport
    this.network = 'tcp',
    this.headerType,
    this.host,
    this.path,
    this.seed,
    this.quicSecurity,
    this.quicKey,
    this.grpcMode,
    this.serviceName,
    // tls / reality
    this.streamSecurity = 'reality',
    this.allowInsecure = false,
    this.sni = '',
    this.fingerprint = 'chrome',
    this.alpn,
    this.publicKey = '',
    this.shortId = '',
    this.spiderX = '',
    // meta
    this.remark = '',
  });

  // ── server ──────────────────────────────────────────────────────────────
  final String address;
  final int port;
  final String uuid;
  final String flow;

  // ── transport ────────────────────────────────────────────────────────────
  final String network;
  final String? headerType;
  final String? host;
  final String? path;
  final String? seed;
  final String? quicSecurity;
  final String? quicKey;
  final String? grpcMode;
  final String? serviceName;

  // ── security ─────────────────────────────────────────────────────────────
  final String streamSecurity; // 'tls' | 'reality' | ''
  final bool allowInsecure;
  final String sni;
  final String fingerprint;
  final String? alpn;
  final String publicKey;
  final String shortId;
  final String spiderX;

  // ── meta ──────────────────────────────────────────────────────────────────
  final String remark;

  // ── factory ───────────────────────────────────────────────────────────────

  /// Parse a VLESS share URL and return a [VpnConfig].
  ///
  /// Throws [FormatException] if the URL is invalid or the scheme is unknown.
  factory VpnConfig.fromUrl(String url) {
    final uri = Uri.parse(url.trim());
    return switch (uri.scheme.toLowerCase()) {
      'vless' => VlessUrl(url: url).toConfig(),
      _ => throw FormatException('Unsupported scheme: ${uri.scheme}'),
    };
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Full V2Ray / Xray JSON string ready for the core engine.
  String get fullConfiguration =>
      VlessUrl.fromConfig(this).getFullConfiguration();

  /// Human-readable label (falls back to address:port).
  String get displayName => remark.isNotEmpty ? remark : '$address:$port';

  VpnConfig copyWith({
    String? address,
    int? port,
    String? uuid,
    String? flow,
    String? network,
    String? headerType,
    String? host,
    String? path,
    String? seed,
    String? quicSecurity,
    String? quicKey,
    String? grpcMode,
    String? serviceName,
    String? streamSecurity,
    bool? allowInsecure,
    String? sni,
    String? fingerprint,
    String? alpn,
    String? publicKey,
    String? shortId,
    String? spiderX,
    String? remark,
  }) => VpnConfig(
    address: address ?? this.address,
    port: port ?? this.port,
    uuid: uuid ?? this.uuid,
    flow: flow ?? this.flow,
    network: network ?? this.network,
    headerType: headerType ?? this.headerType,
    host: host ?? this.host,
    path: path ?? this.path,
    seed: seed ?? this.seed,
    quicSecurity: quicSecurity ?? this.quicSecurity,
    quicKey: quicKey ?? this.quicKey,
    grpcMode: grpcMode ?? this.grpcMode,
    serviceName: serviceName ?? this.serviceName,
    streamSecurity: streamSecurity ?? this.streamSecurity,
    allowInsecure: allowInsecure ?? this.allowInsecure,
    sni: sni ?? this.sni,
    fingerprint: fingerprint ?? this.fingerprint,
    alpn: alpn ?? this.alpn,
    publicKey: publicKey ?? this.publicKey,
    shortId: shortId ?? this.shortId,
    spiderX: spiderX ?? this.spiderX,
    remark: remark ?? this.remark,
  );

  @override
  String toString() => 'VpnConfig($displayName, $network+$streamSecurity)';

  @override
  bool operator ==(Object other) =>
      other is VpnConfig &&
      address == other.address &&
      port == other.port &&
      uuid == other.uuid;

  @override
  int get hashCode => Object.hash(address, port, uuid);
}
