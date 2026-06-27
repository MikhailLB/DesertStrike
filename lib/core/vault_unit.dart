import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/runtime_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VaultUnit — persistent storage facade
// ─────────────────────────────────────────────────────────────────────────────
//  Persists everything the gray flow needs across launches:
//
//    Plain SharedPreferences
//      ├─ runtime mode tag                 (arcade / portal / unset)
//      ├─ url expiry timestamp             (unix seconds)
//      ├─ notification grant flag          (bool)
//      ├─ notification "OS denied" flag    (bool — see pitfall in guide §348)
//      └─ notification skip-until timestamp (unix seconds)
//
//    FlutterSecureStorage (encrypted KeyStore-backed)
//      ├─ last portal URL                  (string)
//      └─ pending one-shot push URL        (string)
//
//  The split is intentional: timestamps and flags are non-sensitive flags
//  that we'd like to survive a backup; the actual URLs are the kind of
//  thing we want behind the Android KeyStore.
// ─────────────────────────────────────────────────────────────────────────────

class VaultUnit {
  // SharedPreferences keys — namespaced "dx." so they never collide with
  // unrelated white-game prefs.
  static const String _kMode = 'dx.mode';
  static const String _kExpiry = 'dx.exp';
  static const String _kPushOk = 'dx.push.ok';
  static const String _kPushOsDenied = 'dx.push.os_denied';
  static const String _kPushSkipUntil = 'dx.push.skip_until';

  // SecureStorage keys — short, opaque names so a strings dump of the
  // shared-prefs db won't reveal what's inside the secure store.
  static const String _sLastPortal = 'lp_v1';
  static const String _sPendingPush = 'pp_v1';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> prime() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── runtime mode ───────────────────────────────────────────────────────────

  RuntimeMode get runtimeMode =>
      RuntimeMode.fromTag(_prefs.getString(_kMode));

  Future<void> setRuntimeMode(RuntimeMode mode) async {
    if (mode == RuntimeMode.unset) {
      await _prefs.remove(_kMode);
    } else {
      await _prefs.setString(_kMode, mode.storageTag);
    }
  }

  // ── portal URL ─────────────────────────────────────────────────────────────

  Future<String?> readLastPortalUrl() => _secure.read(key: _sLastPortal);
  Future<void> writeLastPortalUrl(String url) =>
      _secure.write(key: _sLastPortal, value: url);

  int? get portalExpiresAt => _prefs.getInt(_kExpiry);
  Future<void> setPortalExpiresAt(int unix) async {
    await _prefs.setInt(_kExpiry, unix);
  }

  bool get isPortalExpired {
    final exp = portalExpiresAt;
    if (exp == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= exp;
  }

  // ── notifications ──────────────────────────────────────────────────────────

  bool get isPushGranted => _prefs.getBool(_kPushOk) ?? false;
  Future<void> setPushGranted(bool granted) async {
    await _prefs.setBool(_kPushOk, granted);
  }

  /// "User tapped Deny in the OS dialog" — on Android 13+ the system will
  /// not show the request dialog a second time, so re-prompting is useless.
  /// Without this flag the promo screen would keep coming back every 3 days
  /// and tapping Accept would do nothing — a known pitfall (guide §348).
  bool get isPushOsDenied => _prefs.getBool(_kPushOsDenied) ?? false;
  Future<void> markPushOsDenied() async {
    await _prefs.setBool(_kPushOsDenied, true);
  }

  int? get pushSkipUntil => _prefs.getInt(_kPushSkipUntil);
  Future<void> setPushSkipUntil(int unix) async {
    await _prefs.setInt(_kPushSkipUntil, unix);
  }

  /// Whether the notification promo screen should appear before the
  /// portal WebView opens.
  bool shouldShowPushPromo() {
    if (isPushGranted) return false;
    if (isPushOsDenied) return false;
    final until = pushSkipUntil;
    if (until == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= until;
  }

  // ── one-shot push URL (consumed by bootstrap) ─────────────────────────────

  Future<String?> readPendingPushUrl() => _secure.read(key: _sPendingPush);

  Future<void> stagePushUrl(String url) =>
      _secure.write(key: _sPendingPush, value: url);

  Future<void> clearPendingPushUrl() => _secure.delete(key: _sPendingPush);

  Future<String?> consumePendingPushUrl() async {
    final url = await readPendingPushUrl();
    if (url != null) await clearPendingPushUrl();
    return url;
  }
}
