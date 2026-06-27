import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../models/level_config.dart';
import '../services/progress_service.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final ProgressService _progress = ProgressService.instance;

  Future<void> _openLevel(LevelConfig level) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(level: level)),
    );
    if (mounted) setState(() {}); // refresh unlocks/stars after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(AppAssets.loadingVertical, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xAA160B02)),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Text(
                        'SELECT LEVEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, color: Color(0xFFFFD24A)),
                      const SizedBox(width: 4),
                      Text(
                        '${_progress.totalStars}/${LevelConfig.count * 3}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: LevelConfig.count,
                    itemBuilder: (BuildContext context, int i) {
                      final LevelConfig level = LevelConfig.levels[i];
                      final bool unlocked = _progress.isUnlocked(level.index);
                      final int stars = _progress.starsForLevel(level.index);
                      return _LevelTile(
                        level: level,
                        unlocked: unlocked,
                        stars: stars,
                        onTap: unlocked ? () => _openLevel(level) : null,
                      );
                    },
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

class _LevelTile extends StatelessWidget {
  final LevelConfig level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unlocked
                ? const <Color>[Color(0xFFE9A23C), Color(0xFFB75A1B)]
                : const <Color>[Color(0xFF4A3520), Color(0xFF3A2814)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? const Color(0xFFFFE2AE) : const Color(0xFF6A5236),
            width: 1.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (unlocked) ...<Widget>[
              Text(
                '${level.index}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(3, (int s) {
                  return Icon(
                    s < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: const Color(0xFFFFE082),
                  );
                }),
              ),
            ] else
              const Icon(Icons.lock_rounded, color: Color(0xFFB9A079), size: 32),
          ],
        ),
      ),
    );
  }
}
