import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../cipher/mask.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AgentClient — outbound HTTP with a real-device User-Agent
// ─────────────────────────────────────────────────────────────────────────────
//  Every outbound HTTP request the gray flow makes (dispatch POST, GCD GET,
//  notification image download) goes through this client. The single reason
//  it exists is to override the User-Agent header so that traffic looks like
//  it came from a real mobile browser instead of the Dart/Flutter default.
//
//  The Chrome / WebKit version fragments are XOR-encoded inside the binary
//  (see `cipher/mask.dart`) and decoded lazily on init.
//
//  Both the HTTP layer and the WebView controller share the same string so
//  partner-side fingerprinting stays consistent across the two transports.
// ─────────────────────────────────────────────────────────────────────────────

// XOR-encoded "132.0.6834.163"  — regenerate via tool/encode_keys.dart
const List<int> _chromeFragment = <int>[
  0x5a, 0x15, 0x60, 0xe4, 0x93, 0xff, 0xe8, 0x04, 0x6c, 0xf3, 0x88, 0x1e,
  0xe5, 0xf0,
];

// XOR-encoded "537.36"  — regenerate via tool/encode_keys.dart
const List<int> _webkitFragment = <int>[
  0x5e, 0x15, 0x65, 0xe4, 0x90, 0xe7,
];

String _unwrapChrome() {
  final v = mask(_chromeFragment);
  return v.isEmpty ? '132.0.6834.163' : v;
}

String _unwrapWebkit() {
  final v = mask(_webkitFragment);
  return v.isEmpty ? '537.36' : v;
}

class AgentClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String _ua = '';

  /// Reads actual device fields and assembles the User-Agent. Must be called
  /// once during boot, before any outbound request happens.
  Future<void> warm() async {
    final chromeVer = _unwrapChrome();
    final webkitVer = _unwrapWebkit();

    try {
      final probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await probe.androidInfo;
        final brand = a.brand;
        final model = a.model;
        final apiLevel = a.version.sdkInt;
        final build = a.display.isNotEmpty ? a.display : a.id;
        _ua = 'Mozilla/5.0 (Linux; Android $apiLevel; $brand $model '
            'Build/$build) AppleWebKit/$webkitVer (KHTML, like Gecko) '
            'Chrome/$chromeVer Mobile Safari/$webkitVer';
      } else if (Platform.isIOS) {
        final i = await probe.iosInfo;
        final ver = i.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$webkitVer (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$webkitVer';
      } else {
        _ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UD1A.230803.041) '
            'AppleWebKit/$webkitVer (KHTML, like Gecko) Chrome/$chromeVer '
            'Mobile Safari/$webkitVer';
      }
    } catch (_) {
      _ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UD1A.230803.041) '
          'AppleWebKit/$webkitVer (KHTML, like Gecko) Chrome/$chromeVer '
          'Mobile Safari/$webkitVer';
    }
  }

  String get userAgent => _ua.isEmpty ? 'Mozilla/5.0' : _ua;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Process-wide singleton consumed by every gray-flow service.
final AgentClient agentClient = AgentClient();
