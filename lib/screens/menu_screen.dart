import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../widgets/sand_button.dart';
import 'level_select_screen.dart';
import 'web_view_screen.dart';

/// Main menu: the centered sniper hero and the navigation buttons.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(AppAssets.loadingVertical, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x33000000), Color(0xCC120A02)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  // Sit the hero lower, between the top title and the play
                  // button (vertical bias), horizontally centered.
                  child: Align(
                    alignment: const Alignment(0.0, 0.55),
                    child: Image.asset(
                      AppAssets.hero,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 0, 36, 28),
                  child: Column(
                    children: <Widget>[
                      SandButton(
                        label: 'PLAY',
                        icon: Icons.play_arrow_rounded,
                        primary: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LevelSelectScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SandButton(
                              label: 'Privacy',
                              icon: Icons.privacy_tip_outlined,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const WebViewScreen(
                                    title: 'Privacy Policy',
                                    url: AppLinks.privacyPolicy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SandButton(
                              label: 'Support',
                              icon: Icons.support_agent_outlined,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const WebViewScreen(
                                    title: 'Support',
                                    url: AppLinks.support,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
