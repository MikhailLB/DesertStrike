import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/agent_client.dart';
import '../core/net_sensor.dart';
import '../core/vault_unit.dart';
import '../core/wire_unit.dart';
import '../env/desert_settings.dart';
import 'offline_stage.dart';

/// Optional pre-warm hook called from the bootstrap before the deferred
/// import resolves. Currently a no-op — we keep it so the call site can
/// introduce platform setup work without breaking the deferred contract.
Future<void> primePortalRuntime() async {}

/// Full-screen WebView that hosts the partner URL returned by the dispatch
/// endpoint. Everything Android-specific (autoplay, third-party cookies,
/// file picker, immersive system UI) is wired up here.
class PortalStage extends StatefulWidget {
  final String startUrl;
  final VaultUnit vault;
  final WireUnit wire;
  final NetSensor netSensor;

  const PortalStage({
    super.key,
    required this.startUrl,
    required this.vault,
    required this.wire,
    required this.netSensor,
  });

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _ctrl;
  bool _busy = true;
  bool _offlineShown = false;

  StreamSubscription<List<ConnectivityResult>>? _laneSub;
  Timer? _offlineDebounce;

  String? _lastMainFrameUrl;
  int _redirectRetries = 0;

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agentClient.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _redirectRetries = 0;
          _patchSafeArea();
          _patchKeyboardScroll();
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame != true) return;
          final blurb = err.description.toLowerCase();

          // Affiliate redirect loops: retry up to 3 times from the last
          // known good URL before giving up.
          final isRedirectLoop = blurb.contains('too_many_redirects') ||
              blurb.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (isRedirectLoop &&
              _lastMainFrameUrl != null &&
              _redirectRetries < 3) {
            _redirectRetries++;
            _ctrl.loadRequest(Uri.parse(_lastMainFrameUrl!));
            return;
          }

          // Cover the native WebView error page IMMEDIATELY so the user
          // never sees the bare Android robot screen during the transition.
          if (mounted) setState(() => _busy = true);

          // DNS / disconnect codes mean the network really is gone — skip
          // the redundant probe (it would just slow the transition).
          final dnsOrDrop = blurb.contains('name_not_resolved') ||
              blurb.contains('err_name_not_resolved') ||
              blurb.contains('internet_disconnected') ||
              blurb.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (dnsOrDrop) {
            _goOfflineNow();
          } else {
            _goOfflineIfDown();
          }
        },
        onHttpError: (_) {},
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          final scheme = uri.scheme;
          if (scheme == 'http' ||
              scheme == 'https' ||
              scheme == 'about' ||
              scheme == 'data' ||
              scheme == 'blob') {
            if (req.isMainFrame) _lastMainFrameUrl = req.url;
            return NavigationDecision.navigate;
          }
          _launchExternally(uri);
          return NavigationDecision.prevent;
        },
      ));

    _wireAndroid();
    _ctrl.loadRequest(Uri.parse(widget.startUrl));

    widget.wire.onPortalRedirect = (url) {
      if (mounted) _ctrl.loadRequest(Uri.parse(url));
    };

    _laneSub = widget.netSensor.laneStream.listen((lanes) {
      final allNone = lanes.every((l) => l == ConnectivityResult.none);
      if (!allNone) {
        _offlineDebounce?.cancel();
        return;
      }
      // Debounce by ~700ms so a VPN handoff does not flash the offline
      // screen on a perfectly healthy connection.
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(
        Duration(milliseconds: DesertEnv.offlineDebounceMs),
        _goOfflineNow,
      );
    });
  }

  void _wireAndroid() {
    if (!Platform.isAndroid) return;
    if (_ctrl.platform is! AndroidWebViewController) return;
    final android = _ctrl.platform as AndroidWebViewController;

    // No-gesture autoplay for video content on affiliate landings.
    android.setMediaPlaybackRequiresUserGesture(false);

    // Some sites need third-party cookies for auth flows.
    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(android, true);

    android.setOnShowFileSelector(_pickFiles);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (picked == null) return const <String>[];
      return picked.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  void _goOfflineNow() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final lastUrl = _lastMainFrameUrl ?? widget.startUrl;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => PortalStage(
            startUrl: lastUrl,
            vault: widget.vault,
            wire: widget.wire,
            netSensor: widget.netSensor,
          ),
        ),
      ),
    );
  }

  Future<void> _goOfflineIfDown() async {
    if (_offlineShown) return;
    final reachable = await widget.netSensor.reachable();
    if (reachable || !mounted) return;
    _goOfflineNow();
  }

  Future<void> _launchExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// JS injection: zero out CSS safe-area variables and re-apply on SPA
  /// route changes. Without this, some affiliate pages render a 30-40px
  /// "white bar" at the top on notched Android devices.
  void _patchSafeArea() {
    _ctrl.runJavaScript(r'''
(function(){
  if (window.__dxSafeApplied) return;
  window.__dxSafeApplied = true;
  var STYLE_ID = '__dxSafeStyle';
  var CSS =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-right:0px!important;' +
      '--safe-bottom:0px!important;--safe-left:0px!important;' +
    '}' +
    'html,body,#__nuxt,#__layout,#app,#root,' +
    '.gameview-mobile-header{' +
      'padding-top:0!important;' +
      'padding-left:0!important;' +
      'padding-right:0!important;' +
      'margin-top:0!important;' +
    '}';

  function kbOpen(){
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }

  function apply(){
    if (kbOpen()) return; // never relayout while keyboard is animating
    var head = document.head || document.documentElement;
    if (!head) return;
    var m = document.querySelector('meta[name="viewport"]');
    if (m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content') || '')) {
      var c = (m.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      m.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var el = document.getElementById(STYLE_ID);
    if (!el) {
      el = document.createElement('style');
      el.id = STYLE_ID;
      head.appendChild(el);
    }
    if (el.textContent !== CSS) el.textContent = CSS;
    if (head.lastElementChild !== el) head.appendChild(el);
  }

  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(apply, 80);
      setTimeout(apply, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  /// JS injection: when an input gets focus, scroll it above the keyboard.
  /// We use `behavior:'auto'` (not 'smooth') and a single 350ms delay — two
  /// concurrent scroll animations during a keyboard pop produce visible
  /// jitter on Android (see gray flow guide §"jitter").
  void _patchKeyboardScroll() {
    _ctrl.runJavaScript(r'''
(function(){
  if (window.__dxKbApplied) return;
  window.__dxKbApplied = true;

  function isEditable(el){
    return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
  }

  function scrollToCurrent(){
    var el = document.activeElement;
    if (!isEditable(el)) return;
    var vp = window.visualViewport;
    if (vp) {
      var r = el.getBoundingClientRect();
      var bottom = vp.offsetTop + vp.height;
      if (r.bottom > bottom - 20 || r.top < vp.offsetTop) {
        el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    } else {
      el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
  }

  document.addEventListener('focusin', function(e){
    if (isEditable(e.target)) setTimeout(scrollToCurrent, 350);
  });

  if (window.visualViewport) {
    var prevH = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < prevH) setTimeout(scrollToCurrent, 120);
      prevH = h;
    });
  }
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laneSub?.cancel();
    _offlineDebounce?.cancel();
    widget.wire.onPortalRedirect = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<bool> _swallowBack() async {
    if (await _ctrl.canGoBack()) {
      await _ctrl.goBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final pad = MediaQuery.of(context).viewPadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _swallowBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: isLandscape
                  ? EdgeInsets.only(left: pad.left, right: pad.right)
                  : EdgeInsets.only(top: pad.top),
              child: WebViewWidget(controller: _ctrl),
            ),
            if (_busy)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFE9A23C)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
