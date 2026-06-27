import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/attribution_unit.dart';
import '../core/dispatch_unit.dart';
import '../core/net_sensor.dart';
import '../core/vault_unit.dart';
import '../core/wire_unit.dart';
import '../domain/runtime_mode.dart';
import '../screens/loading_screen.dart' as arcade;
import 'alert_stage.dart';
import 'offline_stage.dart';
import 'portal_stage.dart' deferred as portal;

// ─────────────────────────────────────────────────────────────────────────────
//  BootstrapStage — gray-flow routing orchestrator
// ─────────────────────────────────────────────────────────────────────────────
//  This is the first stage shown when the app boots. It branches on the
//  persisted RuntimeMode:
//
//    RuntimeMode.unset    → first launch, decide via dispatch endpoint
//    RuntimeMode.portal   → returning portal user, refresh URL via dispatch
//    RuntimeMode.arcade   → returning game user, jump straight to the game
//
//  While the decision is being made we render the existing portrait loading
//  artwork (`assets/loading_vertical.webp`) with an animated horizontal
//  progress strip — same visual language as the white-flow loading screen
//  the user already knows.
// ─────────────────────────────────────────────────────────────────────────────

class BootstrapStage extends StatefulWidget {
  final VaultUnit vault;
  final NetSensor netSensor;
  final AttributionUnit attribution;
  final DispatchUnit dispatcher;
  final WireUnit wire;

  const BootstrapStage({
    super.key,
    required this.vault,
    required this.netSensor,
    required this.attribution,
    required this.dispatcher,
    required this.wire,
  });

  @override
  State<BootstrapStage> createState() => _BootstrapStageState();
}

class _BootstrapStageState extends State<BootstrapStage>
    with TickerProviderStateMixin {
  late final AnimationController _strip;
  late final AnimationController _dots;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _strip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..forward();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _run();
  }

  @override
  void dispose() {
    _strip.dispose();
    _dots.dispose();
    super.dispose();
  }

  void _bumpStrip(double target) {
    if (_strip.value < target) {
      _strip.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  // ── orchestration ──────────────────────────────────────────────────────────

  Future<void> _run() async {
    // Register the token-rotation callback BEFORE any await, so a token
    // that rotates while attribution is still in flight isn't lost.
    widget.wire.onTokenRotated = _reportTokenRotation;

    final mode = widget.vault.runtimeMode;
    switch (mode) {
      case RuntimeMode.unset:
        await _firstLaunch();
        break;
      case RuntimeMode.portal:
        await _returningPortal();
        break;
      case RuntimeMode.arcade:
        await _returningArcade();
        break;
    }
  }

  Future<void> _firstLaunch() async {
    _bumpStrip(0.18);

    if (!await widget.netSensor.reachable()) {
      _bumpStrip(1.0);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _toOffline();
      return;
    }

    _bumpStrip(0.40);
    await widget.attribution.boot();
    _bumpStrip(0.62);

    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitConversion(),
      widget.attribution.awaitDeepLink(),
    ]);

    _bumpStrip(0.80);

    final body = await widget.attribution.assembleBody(
      locale: _systemLocale(),
      pushToken: widget.wire.fcmToken,
    );
    final envelope = await widget.dispatcher.hit(body);

    if (envelope.hasPortal) {
      await widget.vault.setRuntimeMode(RuntimeMode.portal);
      await _completeStrip();
      _toPortal(envelope.url!);
    } else {
      await widget.vault.setRuntimeMode(RuntimeMode.arcade);
      await _completeStrip();
      _toArcade();
    }
  }

  Future<void> _returningPortal() async {
    _bumpStrip(0.25);

    if (!await widget.netSensor.reachable()) {
      _bumpStrip(1.0);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _toOffline();
      return;
    }

    // A pending push URL trumps everything — go straight there.
    final pending = await widget.vault.consumePendingPushUrl();
    if (pending != null && pending.isNotEmpty) {
      await _completeStrip();
      _toPortal(pending);
      return;
    }

    final saved = await widget.vault.readLastPortalUrl();

    _bumpStrip(0.45);
    await widget.attribution.boot();
    _bumpStrip(0.60);

    await Future.wait<void>(<Future<void>>[
      widget.attribution
          .awaitConversion()
          .timeout(const Duration(seconds: 10), onTimeout: () {}),
      widget.attribution.awaitDeepLink(),
    ]);

    _bumpStrip(0.80);

    final body = await widget.attribution.assembleBody(
      locale: _systemLocale(),
      pushToken: widget.wire.fcmToken,
    );
    final envelope = await widget.dispatcher.hit(body);

    await _completeStrip();

    if (envelope.hasPortal) {
      _toPortal(envelope.url!);
    } else if (saved != null && saved.isNotEmpty) {
      _toPortal(saved);
    } else {
      _toOffline();
    }
  }

  Future<void> _returningArcade() async {
    _bumpStrip(0.40);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _completeStrip();
    _toArcade();
  }

  Future<void> _completeStrip() async {
    _strip.animateTo(
      1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 420));
  }

  void _reportTokenRotation(String token) async {
    if (widget.vault.runtimeMode != RuntimeMode.portal) return;
    final body = await widget.attribution.assembleBody(
      locale: _systemLocale(),
      pushToken: token,
    );
    widget.dispatcher.hit(body);
  }

  String _systemLocale() {
    try {
      return Platform.localeName.replaceAll('-', '_');
    } catch (_) {
      return 'en_US';
    }
  }

  // ── transitions ────────────────────────────────────────────────────────────

  void _toArcade() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const arcade.LoadingScreen()),
    );
  }

  Future<void> _toPortal(String url) async {
    if (_navigated || !mounted) return;
    _navigated = true;
    await portal.loadLibrary();
    await portal.primePortalRuntime();
    if (!mounted) return;

    if (widget.vault.shouldShowPushPromo()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AlertStage(
            vault: widget.vault,
            wire: widget.wire,
            netSensor: widget.netSensor,
            portalUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => portal.PortalStage(
            startUrl: url,
            vault: widget.vault,
            wire: widget.wire,
            netSensor: widget.netSensor,
          ),
        ),
      );
    }
  }

  void _toOffline() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => BootstrapStage(
            vault: widget.vault,
            netSensor: widget.netSensor,
            attribution: widget.attribution,
            dispatcher: widget.dispatcher,
            wire: widget.wire,
          ),
        ),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14080A),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final bg = orientation == Orientation.portrait
              ? 'assets/loading_vertical.webp'
              : 'assets/loading_horizontal.webp';
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(bg, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0xCC0E0700)],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: orientation == Orientation.portrait ? 32 : 80,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      _label(),
                      const SizedBox(height: 14),
                      _strip2(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _label() {
    return AnimatedBuilder(
      animation: _dots,
      builder: (_, _) {
        final n = 1 + (_dots.value * 3).floor() % 3;
        final dots = '.' * n;
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Loading$dots',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              shadows: <Shadow>[
                Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _strip2() {
    return AnimatedBuilder(
      animation: _strip,
      builder: (_, _) {
        final v = _strip.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  border: Border.all(color: const Color(0xCCFFD79A), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Color(0xFFF2B33D),
                            Color(0xFFD9641E)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(v * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
