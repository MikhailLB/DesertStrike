/// Static configuration for a single sniper level.
///
/// Difficulty ramps up across the 10 levels: more kills required, fewer lives,
/// shorter enemy lifetime (you have less time to react before they shoot back),
/// faster spawns, more simultaneous targets and smaller targets.
class LevelConfig {
  final int index; // 1-based level number
  final int killsRequired;
  final int lives;
  final int enemyLifetimeMs; // time a target stays before it shoots the player
  final int spawnIntervalMs; // delay between target spawns
  final int maxConcurrent; // max targets on screen at once
  final double enemyScale; // visual size multiplier (smaller == harder)

  const LevelConfig({
    required this.index,
    required this.killsRequired,
    required this.lives,
    required this.enemyLifetimeMs,
    required this.spawnIntervalMs,
    required this.maxConcurrent,
    required this.enemyScale,
  });

  static const List<LevelConfig> levels = <LevelConfig>[
    LevelConfig(index: 1, killsRequired: 6, lives: 5, enemyLifetimeMs: 2700, spawnIntervalMs: 1450, maxConcurrent: 1, enemyScale: 1.00),
    LevelConfig(index: 2, killsRequired: 8, lives: 5, enemyLifetimeMs: 2450, spawnIntervalMs: 1300, maxConcurrent: 2, enemyScale: 0.95),
    LevelConfig(index: 3, killsRequired: 10, lives: 5, enemyLifetimeMs: 2250, spawnIntervalMs: 1180, maxConcurrent: 2, enemyScale: 0.90),
    LevelConfig(index: 4, killsRequired: 12, lives: 4, enemyLifetimeMs: 2050, spawnIntervalMs: 1080, maxConcurrent: 2, enemyScale: 0.85),
    LevelConfig(index: 5, killsRequired: 14, lives: 4, enemyLifetimeMs: 1850, spawnIntervalMs: 980, maxConcurrent: 3, enemyScale: 0.80),
    LevelConfig(index: 6, killsRequired: 16, lives: 4, enemyLifetimeMs: 1700, spawnIntervalMs: 880, maxConcurrent: 3, enemyScale: 0.77),
    LevelConfig(index: 7, killsRequired: 18, lives: 3, enemyLifetimeMs: 1550, spawnIntervalMs: 800, maxConcurrent: 3, enemyScale: 0.73),
    LevelConfig(index: 8, killsRequired: 20, lives: 3, enemyLifetimeMs: 1400, spawnIntervalMs: 720, maxConcurrent: 4, enemyScale: 0.69),
    LevelConfig(index: 9, killsRequired: 22, lives: 3, enemyLifetimeMs: 1250, spawnIntervalMs: 650, maxConcurrent: 4, enemyScale: 0.65),
    LevelConfig(index: 10, killsRequired: 25, lives: 3, enemyLifetimeMs: 1100, spawnIntervalMs: 580, maxConcurrent: 4, enemyScale: 0.61),
  ];

  static LevelConfig byIndex(int index) =>
      levels.firstWhere((LevelConfig l) => l.index == index, orElse: () => levels.first);

  static int get count => levels.length;
}
