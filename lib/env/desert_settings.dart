import 'endpoint_codec.dart';
import 'legal_links.dart';
import 'tracker_keys.dart';

/// Central façade for every cross-cutting constant the app needs at runtime.
///
/// Every consumer (HTTP, attribution, push, storage) reads from here so the
/// real values stay in one place. Sensitive strings are decoded lazily on
/// first read via the [unwrap*] helpers.
class DesertEnv {
  DesertEnv._();

  /// Android applicationId / Play Store package name.
  /// Must match `android/app/build.gradle.kts → applicationId`.
  static const String bundleSlug = 'com.chaosdesert.desertstrike';

  /// Same as [bundleSlug] for Android. Reserved for iOS App Store numeric IDs.
  static const String storeSlug = bundleSlug;

  /// Human-readable name shown in notifications and the launcher.
  static const String displayName = 'DesertStrike';

  /// iOS-only App Store numeric ID (unused on Android).
  static const String appStoreId = '';

  /// POST dispatch endpoint — decoded from `endpoint_codec.dart`.
  static String get dispatchEndpoint => unwrapDispatchEndpoint();

  /// AppsFlyer Dev Key — decoded from `tracker_keys.dart`. Empty if not
  /// configured (gray flow degrades gracefully to the white game).
  static String get trackerKey => unwrapTrackerKey();

  /// Firebase project number — decoded from `tracker_keys.dart`. Empty if
  /// not configured.
  static String get messagingProjectNumber => unwrapMessagingProject();

  /// Public legal pages (plaintext — they're public URLs).
  static String get privacyUrl => desertPrivacyUrl;
  static String get supportUrl => desertSupportUrl;

  /// How long to wait before re-showing the push permission promo after a
  /// "Skip". Per spec: three days (in seconds).
  static const int notificationSkipSeconds = 60 * 60 * 24 * 3;

  /// Delay before performing a GCD attribution retry when the SDK first
  /// reports "Organic".
  static const int gcdRetryDelaySeconds = 5;

  /// Connectivity-drop debounce before navigating to the offline stage.
  /// 700 ms absorbs the brief flicker observed while a VPN tunnel boots
  /// (see gray_part_pitfalls.md §3).
  static const int offlineDebounceMs = 700;
}
