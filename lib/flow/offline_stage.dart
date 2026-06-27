import 'package:flutter/material.dart';

/// Full-screen "no internet" stage, illustrated via the pre-rendered Egyptian
/// art assets. The retry button hands control back to whatever builder the
/// caller passes — usually the bootstrap stage or the live portal stage.
class OfflineStage extends StatefulWidget {
  final WidgetBuilder onRetryBuild;

  const OfflineStage({super.key, required this.onRetryBuild});

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  static const _vertBg = 'assets/Nowifi/Vertical_Nowifi_Screen.webp';
  static const _horiBg = 'assets/Nowifi/Horizontal_Nowifi_Screen.webp';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = isLandscape ? _horiBg : _vertBg;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A06),
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg, fit: BoxFit.cover),
            Positioned(
              left: size.width * (isLandscape ? 0.34 : 0.10),
              right: size.width * (isLandscape ? 0.34 : 0.10),
              bottom: size.height * (isLandscape ? 0.08 : 0.10),
              child: ScaleTransition(
                scale: _busy
                    ? const AlwaysStoppedAnimation<double>(0.95)
                    : _pulseAnim,
                child: _DesertRetryButton(
                  busy: _busy,
                  compact: isLandscape,
                  onTap: _retry,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesertRetryButton extends StatefulWidget {
  final bool busy;
  final bool compact;
  final VoidCallback onTap;

  const _DesertRetryButton({
    required this.busy,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_DesertRetryButton> createState() => _DesertRetryButtonState();
}

class _DesertRetryButtonState extends State<_DesertRetryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 14.0 : 18.0;
    return GestureDetector(
      onTapDown: widget.busy ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.busy
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: pad, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.busy
                  ? const <Color>[Color(0xFF6E4A22), Color(0xFF49301A)]
                  : const <Color>[Color(0xFFE9A23C), Color(0xFFB75A1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFE2AE), width: 1.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: widget.busy
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFFE2AE)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Reconnecting…',
                      style: TextStyle(
                        color: Color(0xFFFFE2AE),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.compact ? 17 : 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        shadows: const <Shadow>[
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
