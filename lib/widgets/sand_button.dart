import 'package:flutter/material.dart';

/// A reusable desert-styled button used across the menus.
class SandButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool primary;

  const SandButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = primary
        ? const <Color>[Color(0xFFF4B63E), Color(0xFFD9641E)]
        : const <Color>[Color(0xFF6E4A22), Color(0xFF49301A)];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE2AE), width: 1.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: primary ? 16 : 13, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, color: Colors.white, size: primary ? 26 : 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: primary ? 20 : 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
