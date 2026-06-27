import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'agent_client.dart';
import 'vault_unit.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WireUnit — Firebase Messaging + local notification display
// ─────────────────────────────────────────────────────────────────────────────
//  Three notification paths exist; each handles the `url` data field in a
//  different way and the distinction matters:
//
//    cold tap        → app was killed; FCM delivers via getInitialMessage()
//                       at boot. We STAGE the url in the vault so the
//                       bootstrap stage can pick it up via consumePending().
//
//    warm tap        → app was backgrounded; FCM delivers via
//                       onMessageOpenedApp. We hand the url to the live
//                       portal stage via [onPortalRedirect] — DO NOT persist
//                       (URL is one-shot; next launch must use dispatch).
//
//    foreground push → onMessage → show a local notification; tapping it
//                       fires onDidReceiveNotificationResponse with the
//                       payload. Same treatment as warm tap.
//
//  When Firebase isn't configured yet this whole module fails silently and
//  the app continues working without push.
// ─────────────────────────────────────────────────────────────────────────────

const String _channelId = 'dx_high_importance';
const String _channelName = 'DesertStrike alerts';
const String _channelBody = 'Promotional and gameplay-related messages.';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage _) async {
  // Background isolate — nothing to do; OS displays the notification using
  // the channel + icon metadata declared in the manifest.
}

class WireUnit {
  final VaultUnit _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _booted = false;

  /// Live portal stage assigns this to receive warm push redirects.
  void Function(String url)? onPortalRedirect;

  /// Bootstrap stage assigns this to know the FCM token has rotated so it
  /// can re-POST the dispatch body.
  void Function(String token)? onTokenRotated;

  WireUnit(this._vault);

  String? get fcmToken => _fcmToken;

  Future<void> boot() async {
    if (_booted) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase not configured — keep the app running without push.
      return;
    }

    try {
      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

      await _bootLocalChannel();

      _fcmToken = await _messaging!.getToken();
      _messaging!.onTokenRefresh.listen((t) {
        _fcmToken = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_renderForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleWarmTap);

      final cold = await _messaging!.getInitialMessage();
      if (cold != null) {
        await _handleColdTap(cold);
      }

      _booted = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WireUnit] boot failed: $e');
    }
  }

  Future<void> _bootLocalChannel() async {
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        try {
          final map = jsonDecode(payload);
          if (map is Map && map['url'] is String) {
            final url = map['url'] as String;
            if (url.isNotEmpty) onPortalRedirect?.call(url);
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final androidImpl =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelBody,
          importance: Importance.high,
        ),
      );
    }
  }

  /// Request POST_NOTIFICATIONS (Android 13+) / system push permission (iOS).
  /// Stores the result in the vault; if the user denies at the OS level we
  /// also set the "OS denied" flag so we don't re-prompt forever.
  Future<bool> askPermission() async {
    final m = _messaging;
    if (m == null) {
      await _vault.setPushGranted(false);
      return false;
    }
    try {
      final settings = await m.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final s = settings.authorizationStatus;
      final granted = s == AuthorizationStatus.authorized ||
          s == AuthorizationStatus.provisional;
      await _vault.setPushGranted(granted);
      if (s == AuthorizationStatus.denied) {
        await _vault.markPushOsDenied();
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  // ── push handlers ──────────────────────────────────────────────────────────

  Future<void> _handleColdTap(RemoteMessage m) async {
    final url = m.data['url'];
    if (url is String && url.isNotEmpty) {
      await _vault.stagePushUrl(url);
    }
  }

  void _handleWarmTap(RemoteMessage m) {
    final url = m.data['url'];
    if (url is String && url.isNotEmpty) {
      onPortalRedirect?.call(url);
    }
  }

  Future<void> _renderForeground(RemoteMessage m) async {
    if (!Platform.isAndroid) return; // iOS handles its own banners
    final notif = m.notification;
    if (notif == null) return;

    AndroidNotificationDetails? details;
    final imageUrl = notif.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _grabImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelBody,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelBody,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    final payload = m.data.isNotEmpty ? jsonEncode(m.data) : null;
    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final r = await agentClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }
}
