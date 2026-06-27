import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../models/level_config.dart';
import '../services/progress_service.dart';

/// A single on-screen target.
class _Target {
  final int id;
  final Offset fraction; // center, 0..1 of the playfield
  final double scale;
  final int bornMs;
  final int lifetimeMs;

  _Target({
    required this.id,
    required this.fraction,
    required this.scale,
    required this.bornMs,
    required this.lifetimeMs,
  });
}

enum _Phase { playing, won, lost }

class GameScreen extends StatefulWidget {
  final LevelConfig level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Duration _tick = Duration(milliseconds: 30);

  final Stopwatch _clock = Stopwatch();
  final Random _rng = Random();
  final List<_Target> _targets = <_Target>[];

  Timer? _loop;
  int _nextId = 0;
  int _lastSpawnMs = 0;
  int _elapsedMs = 0;

  late int _lives;
  int _kills = 0;
  int _shots = 0;
  int _hits = 0;
  _Phase _phase = _Phase.playing;
  bool _paused = false;

  Offset? _aim; // crosshair position in playfield-local pixels
  Size _field = Size.zero;

  @override
  void initState() {
    super.initState();
    _lives = widget.level.lives;
    _clock.start();
    _loop = Timer.periodic(_tick, _onTick);
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  // --- core loop -----------------------------------------------------------

  void _onTick(Timer _) {
    if (_phase != _Phase.playing || _paused || _field == Size.zero) return;
    _elapsedMs = _clock.elapsedMilliseconds;

    // Expire targets that "shot back".
    _targets.removeWhere((_Target t) {
      final bool expired = _elapsedMs - t.bornMs >= t.lifetimeMs;
      if (expired) _lives--;
      return expired;
    });

    if (_lives <= 0) {
      setState(() => _phase = _Phase.lost);
      return;
    }

    // Spawn new targets up to the level cap.
    if (_targets.length < widget.level.maxConcurrent &&
        _elapsedMs - _lastSpawnMs >= widget.level.spawnIntervalMs) {
      final _Target? t = _makeTarget();
      if (t != null) {
        _targets.add(t);
        _lastSpawnMs = _elapsedMs;
      }
    }

    // Rebuild every tick so the countdown bars shrink smoothly.
    setState(() {});
  }

  _Target? _makeTarget() {
    const double minDist = 0.20;
    for (int attempt = 0; attempt < 14; attempt++) {
      final double x = 0.12 + _rng.nextDouble() * 0.76;
      final double y = 0.50 + _rng.nextDouble() * 0.36; // desert ground area
      final Offset candidate = Offset(x, y);
      final bool tooClose = _targets.any(
        (_Target t) => (t.fraction - candidate).distance < minDist,
      );
      if (!tooClose) {
        return _Target(
          id: _nextId++,
          fraction: candidate,
          scale: widget.level.enemyScale,
          bornMs: _elapsedMs,
          lifetimeMs: widget.level.enemyLifetimeMs,
        );
      }
    }
    return null;
  }

  double get _enemyBaseSize => _field.shortestSide * 0.32;

  // --- input ---------------------------------------------------------------

  void _onPointerDown(Offset local) {
    if (_phase != _Phase.playing || _paused) return;
    setState(() {
      _aim = local;
      _shots++;
      _fireAt(local);
    });
  }

  void _onPointerMove(Offset local) {
    if (_phase != _Phase.playing || _paused) return;
    setState(() => _aim = local);
  }

  void _fireAt(Offset point) {
    _Target? best;
    double bestDist = double.infinity;
    final double base = _enemyBaseSize;
    for (final _Target t in _targets) {
      final Offset center = Offset(
        t.fraction.dx * _field.width,
        t.fraction.dy * _field.height,
      );
      final double radius = base * t.scale * 0.5;
      final double d = (center - point).distance;
      if (d <= radius && d < bestDist) {
        bestDist = d;
        best = t;
      }
    }
    if (best != null) {
      _targets.remove(best);
      _kills++;
      _hits++;
      if (_kills >= widget.level.killsRequired) {
        _win();
      }
    }
  }

  // --- outcomes ------------------------------------------------------------

  int _computeStars() {
    final int lost = widget.level.lives - _lives;
    if (lost == 0) return 3;
    if (lost <= 1) return 2;
    return 1;
  }

  Future<void> _win() async {
    _phase = _Phase.won;
    final int stars = _computeStars();
    await ProgressService.instance.completeLevel(widget.level.index, stars);
    if (mounted) setState(() {});
  }

  void _restart() {
    setState(() {
      _targets.clear();
      _nextId = 0;
      _lastSpawnMs = 0;
      _elapsedMs = 0;
      _kills = 0;
      _shots = 0;
      _hits = 0;
      _lives = widget.level.lives;
      _phase = _Phase.playing;
      _paused = false;
      _aim = null;
      _clock
        ..reset()
        ..start();
    });
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _clock.stop();
      } else {
        _clock.start();
      }
    });
  }

  void _goToNextLevel() {
    final int next = widget.level.index + 1;
    if (next > LevelConfig.count) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: LevelConfig.byIndex(next)),
      ),
    );
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _field = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(AppAssets.bgPlay, fit: BoxFit.cover),
              _buildPlayfield(),
              _buildHud(),
              if (_paused) _buildPauseOverlay(),
              if (_phase == _Phase.won) _buildWinOverlay(),
              if (_phase == _Phase.lost) _buildLoseOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayfield() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails d) => _onPointerDown(d.localPosition),
      onPanStart: (DragStartDetails d) => _onPointerMove(d.localPosition),
      onPanUpdate: (DragUpdateDetails d) => _onPointerMove(d.localPosition),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final _Target t in _targets) _buildTarget(t),
          if (_aim != null) _buildCrosshair(_aim!),
        ],
      ),
    );
  }

  Widget _buildTarget(_Target t) {
    final double size = _enemyBaseSize * t.scale;
    final double left = t.fraction.dx * _field.width - size / 2;
    final double top = t.fraction.dy * _field.height - size / 2;
    final double remaining =
        (1 - (_elapsedMs - t.bornMs) / t.lifetimeMs).clamp(0.0, 1.0);
    final Color barColor =
        Color.lerp(const Color(0xFFE53935), const Color(0xFF66BB6A), remaining)!;
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Column(
          children: <Widget>[
            // Countdown bar — how long before this target shoots back.
            Container(
              height: 5,
              width: size * 0.7,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: remaining,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(child: Image.asset(AppAssets.enemy, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }

  Widget _buildCrosshair(Offset pos) {
    final double size = _field.shortestSide * 0.38;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Image.asset(AppAssets.sight, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _hudChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.gps_fixed_rounded,
                      color: Color(0xFFFFD79A), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'LV. ${widget.level.index}',
                    style: _hudTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _hudChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.military_tech_rounded,
                      color: Color(0xFFFFD79A), size: 18),
                  const SizedBox(width: 6),
                  Text('$_kills / ${widget.level.killsRequired}',
                      style: _hudTextStyle),
                ],
              ),
            ),
            const Spacer(),
            // Compact lives counter (heart + number) so the row never
            // overflows regardless of how many lives the level grants.
            _hudChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.favorite_rounded,
                      color: Color(0xFFFF5A5A), size: 18),
                  const SizedBox(width: 5),
                  Text('$_lives', style: _hudTextStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _togglePause,
              child: _hudChip(
                child: const Icon(Icons.pause_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _hudTextStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 14,
    letterSpacing: 0.5,
  );

  Widget _hudChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB3120A02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FFD79A)),
      ),
      child: child,
    );
  }

  // --- overlays ------------------------------------------------------------

  Widget _scrim({required Widget child}) {
    return Positioned.fill(
      // Opaque barrier so taps behind the dialog never reach the playfield;
      // the buttons inside remain fully interactive.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: const Color(0xCC0B0600),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _panel({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF3A2613), Color(0xFF24160A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD79A), width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _overlayButton(String label, IconData icon, VoidCallback onTap,
      {bool primary = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor:
                primary ? const Color(0xFFE9842A) : const Color(0xFF8A5A28),
            foregroundColor: Colors.white,
            iconColor: Colors.white,
            side: const BorderSide(color: Color(0xFFFFE2AE), width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return _scrim(
      child: _panel(
        children: <Widget>[
          const Text('PAUSED',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          _overlayButton('Resume', Icons.play_arrow_rounded, _togglePause,
              primary: true),
          _overlayButton('Restart', Icons.refresh_rounded, _restart),
          _overlayButton('Main Menu', Icons.home_rounded,
              () => Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst)),
        ],
      ),
    );
  }

  Widget _buildWinOverlay() {
    final int stars = _computeStars();
    final double accuracy = _shots == 0 ? 0 : _hits / _shots * 100;
    final bool hasNext = widget.level.index < LevelConfig.count;
    return _scrim(
      child: _panel(
        children: <Widget>[
          const Text('VICTORY!',
              style: TextStyle(
                  color: Color(0xFFFFE082),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(3, (int i) {
              return Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFFFD24A),
                size: 44,
              );
            }),
          ),
          const SizedBox(height: 12),
          Text('Accuracy: ${accuracy.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 8),
          if (hasNext)
            _overlayButton(
                'Next Level', Icons.skip_next_rounded, _goToNextLevel,
                primary: true)
          else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('All levels completed!',
                  style: TextStyle(
                      color: Color(0xFFFFE082), fontWeight: FontWeight.w700)),
            ),
          _overlayButton('Restart', Icons.refresh_rounded, _restart),
          _overlayButton('Main Menu', Icons.home_rounded,
              () => Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst)),
        ],
      ),
    );
  }

  Widget _buildLoseOverlay() {
    return _scrim(
      child: _panel(
        children: <Widget>[
          const Text('DEFEAT',
              style: TextStyle(
                  color: Color(0xFFFF7A7A),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Targets eliminated: $_kills / ${widget.level.killsRequired}',
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          _overlayButton('Try Again', Icons.refresh_rounded, _restart,
              primary: true),
          _overlayButton('Main Menu', Icons.home_rounded,
              () => Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst)),
        ],
      ),
    );
  }
}
