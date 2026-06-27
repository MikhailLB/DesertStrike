import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../env/desert_settings.dart';
import '../env/endpoint_codec.dart';
import 'agent_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AttributionUnit — AppsFlyer wrapper that also assembles the dispatch body
// ─────────────────────────────────────────────────────────────────────────────
//  Responsibilities:
//
//    1. Initialise the AppsFlyer SDK with the project Dev Key.
//    2. Capture three callbacks the SDK fires after install:
//         - onInstallConversionData  → primary attribution payload
//         - onAppOpenAttribution     → returning-user attribution
//         - onDeepLinking            → OneLink deep link click event
//    3. If the first payload reports af_status == "Organic", wait a few
//       seconds and ask the GCD endpoint directly — AppsFlyer is known to
//       occasionally return a false-organic result on the very first call
//       (gray flow guide §"Organic False-Positive Fix").
//    4. Provide a single `assembleBody()` helper that merges all three
//       payloads with a stable priority order and tacks the device-side
//       fields (af_id, bundle_id, os, store_id, locale, push_token,
//       firebase_project_id) on top.
//
//  Failure mode: if the SDK can't initialise (e.g. the Dev Key is still a
//  placeholder), everything keeps working — the attribution payloads are
//  empty maps and the dispatch endpoint will simply receive the device-side
//  fields. The backend can decide what to do with that.
// ─────────────────────────────────────────────────────────────────────────────

class AttributionUnit {
  AppsflyerSdk? _sdk;
  bool _booted = false;

  Map<String, dynamic> _conversionPayload = const {};
  Map<String, dynamic> _appOpenPayload = const {};
  Map<String, dynamic> _deepLinkPayload = const {};

  final Completer<void> _conversionReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  /// Register all callbacks and call `initSdk`. Idempotent — safe to call
  /// from a returning-user flow that has no need to re-init.
  Future<void> boot() async {
    if (_booted) return;
    _booted = true;

    final key = DesertEnv.trackerKey;
    if (key.isEmpty) {
      // Dev Key not provided yet — finish both completers immediately so
      // call sites that await them don't hang.
      if (!_conversionReady.isCompleted) _conversionReady.complete();
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      return;
    }

    try {
      final options = AppsFlyerOptions(
        afDevKey: key,
        appId: DesertEnv.appStoreId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 10,
      );

      _sdk = AppsflyerSdk(options);

      _sdk!.onInstallConversionData((dynamic data) async {
        final payload = _extractPayload(data);
        if (payload['af_status'] == 'Organic') {
          // The SDK occasionally mis-flags paid installs as organic on the
          // very first callback. Wait briefly, then ask GCD directly.
          await Future<void>.delayed(
            const Duration(seconds: DesertEnv.gcdRetryDelaySeconds),
          );
          final retried = await _hitGcd();
          _conversionPayload = retried ?? payload;
        } else {
          _conversionPayload = payload;
        }
        if (!_conversionReady.isCompleted) _conversionReady.complete();
      });

      _sdk!.onAppOpenAttribution((dynamic data) {
        _appOpenPayload = _extractPayload(data);
      });

      _sdk!.onDeepLinking((DeepLinkResult result) {
        try {
          final click = result.deepLink?.clickEvent;
          if (click != null) {
            _deepLinkPayload = Map<String, dynamic>.from(click);
          }
        } catch (_) {}
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });

      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AttributionUnit] init failed: $e');
      }
      if (!_conversionReady.isCompleted) _conversionReady.complete();
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    }
  }

  Future<String?> readDeviceId() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Await the install-conversion callback with a 30-second ceiling.
  Future<void> awaitConversion() async {
    try {
      await _conversionReady.future
          .timeout(const Duration(seconds: 30), onTimeout: () {});
    } catch (_) {}
  }

  /// Await the deep-link callback with a 5-second ceiling.
  Future<void> awaitDeepLink() async {
    try {
      await _deepLinkReady.future
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (_) {}
  }

  /// Build the merged map that becomes the POST body for the dispatch
  /// endpoint. Order of precedence (first wins):
  ///   1. install-conversion data
  ///   2. deep link click event (putIfAbsent — does not overwrite)
  ///   3. app-open attribution     (putIfAbsent)
  /// Device-side fields are then forced on top.
  Future<Map<String, dynamic>> assembleBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    body.addAll(_conversionPayload);
    _deepLinkPayload.forEach((k, v) => body.putIfAbsent(k, () => v));
    _appOpenPayload.forEach((k, v) => body.putIfAbsent(k, () => v));

    final uid = await readDeviceId();
    body['af_id'] = uid ?? '';
    body['bundle_id'] = DesertEnv.bundleSlug;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = DesertEnv.storeSlug;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final firebaseProj = DesertEnv.messagingProjectNumber;
    if (firebaseProj.isNotEmpty) {
      body['firebase_project_id'] = firebaseProj;
    }

    if (kDebugMode) {
      debugPrint('[AttributionUnit] body=${jsonEncode(body)}');
    }
    return body;
  }

  // ── internal helpers ───────────────────────────────────────────────────────

  Map<String, dynamic> _extractPayload(dynamic data) {
    try {
      if (data is Map) {
        final inner = data['payload'];
        if (inner is Map) {
          return Map<String, dynamic>.from(inner);
        }
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>?> _hitGcd() async {
    final uid = await readDeviceId();
    if (uid == null || uid.isEmpty) return null;

    final appId = Platform.isIOS
        ? (DesertEnv.appStoreId.isNotEmpty
            ? DesertEnv.appStoreId
            : DesertEnv.bundleSlug)
        : DesertEnv.bundleSlug;

    final url = unwrapGcdEndpoint(
      bundleId: DesertEnv.bundleSlug,
      deviceId: uid,
      appId: appId,
    );
    if (url.isEmpty) return null;

    try {
      final r = await agentClient.get(
        Uri.parse(url),
        headers: {
          'authorization': 'Bearer ${DesertEnv.trackerKey}',
          'accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final json = jsonDecode(r.body);
        if (json is Map<String, dynamic>) return json;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionUnit] GCD retry failed: $e');
    }
    return null;
  }
}
