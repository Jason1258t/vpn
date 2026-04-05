import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vpn/data/cache_manager.dart';

part 'protocol_manager.g.dart';

@riverpod
ProtocolManager protocolManager(Ref ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return ProtocolManager(cacheManager);
}

class ProtocolManager {
  final VpnCacheManager _cacheManager;
  final ConfigurationStore _store = ConfigurationStore();

  ProtocolManager(this._cacheManager);

  static final defaultProtocol = AvailableProtocols.vlessReality;

  String? _currentProtocol;

  Future<String> get currentConnectUrl async =>
      _store.getConfigForProtocol(await getProtocol()).shareLink;

  Future<void> setProtocol(String protocol) async {
    _currentProtocol = protocol;
    await _cacheManager.setProtocol(protocol);
  }

  Future<String> getProtocol() async {
    if (_currentProtocol != null) {
      return _currentProtocol!;
    } else {
      final p = await _loadProtocol();
      _currentProtocol = p;
    }
    return _currentProtocol!;
  }

  Future<String> _loadProtocol() async {
    final cachedProtocol = await _cacheManager.getProtocol();
    return cachedProtocol ?? defaultProtocol;
  }
}

abstract class AvailableProtocols {
  static const vlessReality = 'vless_reality';
  static const vlessXHttpTLS = 'vless_xhttp_tls';
  static const vlessXHttp = 'vless_xhttp';
}

class VpnConfig {
  final String shareLink;
  final String protocol;

  VpnConfig(this.shareLink, this.protocol);
}

abstract class DefaultConfigs {
  static final vlessRealityConfigUrl = dotenv.get('VLESS_REALITY_LINK');
  static final vlessXHttpTLSConfigUrl = dotenv.get('VLESS_XHTTP_TLS_LINK');
  static final vlessXHttpConfigUrl = dotenv.get('VLESS_XHTTP_LINK');
}

class ConfigurationStore {
  final Map<String, VpnConfig> _configs = {};

  ConfigurationStore() {
    initialize();
  }

  VpnConfig getConfigForProtocol(String protocol) {
    return _configs[protocol]!;
  }

  void initialize() {
    _configs[AvailableProtocols.vlessReality] = VpnConfig(
      DefaultConfigs.vlessRealityConfigUrl,
      AvailableProtocols.vlessReality,
    );
    _configs[AvailableProtocols.vlessXHttpTLS] = VpnConfig(
      DefaultConfigs.vlessXHttpTLSConfigUrl,
      AvailableProtocols.vlessXHttpTLS,
    );
    _configs[AvailableProtocols.vlessXHttp] = VpnConfig(
      DefaultConfigs.vlessXHttpConfigUrl,
      AvailableProtocols.vlessXHttp,
    );
  }
}
