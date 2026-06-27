import 'package:flutter/material.dart';

import '../core/net_sensor.dart';
import '../core/vault_unit.dart';
import '../core/wire_unit.dart';
import '../env/desert_settings.dart';
import 'portal_stage.dart' deferred as portal;

/// Notification permission promo, shown on top of the pre-rendered Egyptian
/// "allow notifications" art. Two affordances:
///   • "Accept" → ask the OS permission, then forward to the portal.
///   • "Skip"   → schedule a 3-day cool-down and forward to the portal.
class AlertStage extends StatefulWidget {
  final VaultUnit vault;
  final WireUnit wire;
  final NetSensor netSensor;
  final String portalUrl;

  const AlertStage({
    super.key,
    required this.vault,
    required this.wire,
    required this.netSensor,
    required this.portalUrl,
  });

  @override
  State<AlertStage> createState() => _AlertStageState();
}

class _AlertStageState extends State<AlertStage> {
  static const _vertBg =
      'assets/Notifications/Vertical_Notifications_Screen.webp';
  static const _horiBg =
      'assets/Notifications/Horizontal_Notifications_Screen.webp';

  bool _navigated = false;

  Future<void> _onAccept() async {
    if (_navigated) return;
    final granted = await widget.wire.askPermission();
    if (!granted) {
      final cool = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          DesertEnv.notificationSkipSeconds;
      await widget.vault.setPushSkipUntil(cool);
    }
    if (!mounted) return;
    await _forwardToPortal();
  }

  Future<void> _onSkip() async {
    if (_navigated) return;
    final cool = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        DesertEnv.notificationSkipSeconds;
    await widget.vault.setPushSkipUntil(cool);
    if (!mounted) return;
    await _forwardToPortal();
  }

  Future<void> _forwardToPortal() async {
    if (_navigated) return;
    _navigated = true;
    await portal.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => portal.PortalStage(
          startUrl: widget.portalUrl,
          vault: widget.vault,
          wire: widget.wire,
          netSensor: widget.netSensor,
        ),
      ),
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
            if (!isLandscape)
              Positioned(
                left: size.width * 0.08,
                right: size.width * 0.08,
                bottom: size.height * 0.06,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PharaohAcceptButton(onTap: _onAccept),
                    const SizedBox(height: 14),
                    _DesertSkipLink(onTap: _onSkip),
                  ],
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: size.height * 0.06,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: size.width * 0.34,
                      child: _PharaohAcceptButton(
                        onTap: _onAccept,
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DesertSkipLink(onTap: _onSkip, compact: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PharaohAcceptButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _PharaohAcceptButton({required this.onTap, this.compact = false});
  @override
  State<_PharaohAcceptButton> createState() => _PharaohAcceptButtonState();
}

class _PharaohAcceptButtonState extends State<_PharaohAcceptButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  late final Animation<double> _shineAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _shineAnim = Tween<double>(begin: 0.28, end: 0.78).animate(
      CurvedAnimation(parent: _shine, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vPad = widget.compact ? 12.0 : 18.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _shineAnim,
        builder: (_, _) => AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: vPad),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pressed
                    ? const <Color>[Color(0xFFCB8617), Color(0xFF8B4D14)]
                    : const <Color>[Color(0xFFFFCF52), Color(0xFFD9641E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFFE9B0),
                width: 1.6,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFFB347)
                      .withValues(alpha: _pressed ? 0.18 : _shineAnim.value),
                  blurRadius: _pressed ? 6 : 18 + _shineAnim.value * 10,
                  spreadRadius: _pressed ? 0 : _shineAnim.value * 2,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Accept',
                style: TextStyle(
                  color: const Color(0xFF2C1606),
                  fontSize: widget.compact ? 17 : 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesertSkipLink extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _DesertSkipLink({required this.onTap, this.compact = false});
  @override
  State<_DesertSkipLink> createState() => _DesertSkipLinkState();
}

class _DesertSkipLinkState extends State<_DesertSkipLink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.55 : 0.92,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Text(
            'Skip',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 16 : 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              shadows: const <Shadow>[
                Shadow(
                  color: Colors.black87,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
