import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_assets.dart';
import 'menu_screen.dart';

/// First screen the user sees. Supports BOTH portrait and landscape: it picks
/// the matching background artwork and shows a left-to-right progress bar that
/// only reaches 100% right before the game launches.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _dotsController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // The loading screen is allowed to rotate freely.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _dotsController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
          ..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((AnimationStatus status) {
        // The bar is full only here, immediately before we launch the game.
        if (status == AnimationStatus.completed) {
          _goToMenu();
        }
      });
    _progressController.forward();
  }

  Future<void> _goToMenu() async {
    if (_navigated) return;
    _navigated = true;

    // From here on the experience is strictly portrait.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionsBuilder: (_, Animation<double> anim, _, Widget child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A1608),
      body: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          final bool isPortrait = orientation == Orientation.portrait;
          final String bg = isPortrait
              ? AppAssets.loadingVertical
              : AppAssets.loadingHorizontal;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(bg, fit: BoxFit.cover),
              // Subtle dark gradient at the bottom for legible text/bar.
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
                    horizontal: isPortrait ? 32 : 80,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      _buildLoadingLabel(),
                      const SizedBox(height: 14),
                      _buildProgressBar(),
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

  Widget _buildLoadingLabel() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (BuildContext context, _) {
        final int dotCount = 1 + (_dotsController.value * 3).floor() % 3;
        final String dots = '.' * dotCount;
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

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (BuildContext context, _) {
        final double value = _progressController.value;
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
                    // Fills strictly left -> right.
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFFF2B33D), Color(0xFFD9641E)],
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
                '${(value * 100).round()}%',
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
