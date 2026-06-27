import 'package:shared_preferences/shared_preferences.dart';

/// Persists how far the player has progressed and per-level star ratings.
class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const String _kUnlockedLevel = 'unlocked_level';
  static const String _kStarsPrefix = 'stars_level_';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Highest level the player is allowed to enter (1-based). Level 1 is always
  /// available.
  int get unlockedLevel => _prefs?.getInt(_kUnlockedLevel) ?? 1;

  int starsForLevel(int level) => _prefs?.getInt('$_kStarsPrefix$level') ?? 0;

  bool isUnlocked(int level) => level <= unlockedLevel;

  /// Records a completed level, unlocking the next one and keeping the best
  /// star result.
  Future<void> completeLevel(int level, int stars) async {
    await init();
    final int bestStars = starsForLevel(level);
    if (stars > bestStars) {
      await _prefs!.setInt('$_kStarsPrefix$level', stars);
    }
    if (level + 1 > unlockedLevel) {
      await _prefs!.setInt(_kUnlockedLevel, level + 1);
    }
  }

  int get totalStars {
    int sum = 0;
    for (int i = 1; i <= 10; i++) {
      sum += starsForLevel(i);
    }
    return sum;
  }
}
