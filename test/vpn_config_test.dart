import 'dart:convert';
import 'package:test/test.dart';
import 'package:vpn/vpn_service/models/vpn_config.dart';
import 'package:vpn/vpn_service/v2ray/vless_url.dart';

void main() {
  // Real-world VLESS+Reality share link (sanitised)
  const realityUrl =
      'vless://a3b4c5d6-dead-beef-cafe-123456789abc'
      '@198.51.100.1:443'
      '?type=tcp'
      '&security=reality'
      '&sni=www.example.com'
      '&fp=chrome'
      '&pbk=wC9sED1Z2V9iMdnlE9UnjsHR6JRO9Qq9BCN8zDEHBXA%3D'
      '&sid=4a6f8b2c'
      '&flow=xtls-rprx-vision'
      '#My%20Server';

  group('VpnConfig.fromUrl — VLESS+Reality', () {
    late VpnConfig cfg;

    setUp(() => cfg = VpnConfig.fromUrl(realityUrl));

    test('address is parsed', () => expect(cfg.address, '198.51.100.1'));
    test('port is parsed', () => expect(cfg.port, 443));
    test('uuid is parsed',
        () => expect(cfg.uuid, 'a3b4c5d6-dead-beef-cafe-123456789abc'));
    test('flow is parsed', () => expect(cfg.flow, 'xtls-rprx-vision'));
    test('network is tcp', () => expect(cfg.network, 'tcp'));
    test('security is reality', () => expect(cfg.streamSecurity, 'reality'));
    test('sni is parsed', () => expect(cfg.sni, 'www.example.com'));
    test('fingerprint is chrome', () => expect(cfg.fingerprint, 'chrome'));
    test('remark is decoded', () => expect(cfg.remark, 'My Server'));
    test('publicKey is parsed', () => expect(cfg.publicKey, isNotEmpty));
    test('shortId is parsed', () => expect(cfg.shortId, '4a6f8b2c'));
    test('allowInsecure defaults false', () => expect(cfg.allowInsecure, false));
  });

  group('VlessUrl.fromConfig → round-trip', () {
    test('round-trip produces identical parsed fields', () {
      final original = VpnConfig.fromUrl(realityUrl);
      final rebuilt = VlessUrl.fromConfig(original).toConfig();

      expect(rebuilt.address, original.address);
      expect(rebuilt.port, original.port);
      expect(rebuilt.uuid, original.uuid);
      expect(rebuilt.flow, original.flow);
      expect(rebuilt.sni, original.sni);
      expect(rebuilt.streamSecurity, original.streamSecurity);
      expect(rebuilt.publicKey, original.publicKey);
      expect(rebuilt.shortId, original.shortId);
    });
  });

  group('fullConfiguration JSON', () {
    test('contains protocol: vless', () {
      final cfg = VpnConfig.fromUrl(realityUrl);
      final json = jsonDecode(cfg.fullConfiguration) as Map<String, dynamic>;
      final outbounds = json['outbounds'] as List;
      final proxy =
          outbounds.firstWhere((o) => o['tag'] == 'proxy') as Map<String, dynamic>;
      expect(proxy['protocol'], 'vless');
    });

    test('realitySettings present, tlsSettings absent', () {
      final cfg = VpnConfig.fromUrl(realityUrl);
      final json = jsonDecode(cfg.fullConfiguration) as Map<String, dynamic>;
      final outbounds = json['outbounds'] as List;
      final proxy =
          outbounds.firstWhere((o) => o['tag'] == 'proxy') as Map<String, dynamic>;
      final stream = proxy['streamSettings'] as Map<String, dynamic>;
      expect(stream.containsKey('realitySettings'), true);
      expect(stream.containsKey('tlsSettings'), false);
    });

    test('flow is present in user object', () {
      final cfg = VpnConfig.fromUrl(realityUrl);
      final json = jsonDecode(cfg.fullConfiguration) as Map<String, dynamic>;
      final outbounds = json['outbounds'] as List;
      final proxy =
          outbounds.firstWhere((o) => o['tag'] == 'proxy') as Map<String, dynamic>;
      final user =
          (proxy['settings']['vnext'][0]['users'] as List).first as Map;
      expect(user['flow'], 'xtls-rprx-vision');
    });

    test('no null values in JSON', () {
      final cfg = VpnConfig.fromUrl(realityUrl);
      final raw = cfg.fullConfiguration;
      expect(raw.contains(': null'), false);
      expect(raw.contains(':null'), false);
    });

    test('inbound SOCKS on 127.0.0.1:1080', () {
      final cfg = VpnConfig.fromUrl(realityUrl);
      final json = jsonDecode(cfg.fullConfiguration) as Map<String, dynamic>;
      final inbound = (json['inbounds'] as List).first as Map;
      expect(inbound['protocol'], 'socks');
      expect(inbound['listen'], '127.0.0.1');
      expect(inbound['port'], 1080);
    });
  });

  group('Error handling', () {
    test('throws FormatException for unsupported scheme', () {
      expect(
        () => VpnConfig.fromUrl('vmess://somedata'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for missing UUID', () {
      expect(
        () => VlessUrl(url: 'vless://@host:443').toConfig(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
