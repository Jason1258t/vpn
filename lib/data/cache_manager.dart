import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'cache_manager.g.dart';

@riverpod
VpnCacheManager cacheManager(Ref ref) {
  final prefs = SharedPreferencesAsync();
  return VpnCacheManager(prefs);
}

class VpnCacheManager {
  final SharedPreferencesAsync _prefs;
  static const _keyStartTime = 'vpn_start_time';

  VpnCacheManager(this._prefs);

  Future<void> saveStartTime(DateTime time) async {
    await _prefs.setInt(_keyStartTime, time.millisecondsSinceEpoch);
  }

  Future<void> clearStartTime() async {
    await _prefs.remove(_keyStartTime);
  }

  Future<DateTime?> getStartTime() async {
    final ms = await _prefs.getInt(_keyStartTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }
}
