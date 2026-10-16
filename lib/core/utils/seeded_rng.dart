/// Deterministic PRNG so AI games, tests, and (later) cross-platform
/// validation replay identically from a seed. Same idea as bingo's
/// seeded cartela generator: same seed → same sequence, forever.
class SeededRng {
  SeededRng(this._seed);

  factory SeededRng.fromNow() =>
      SeededRng(DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF);

  int _seed;

  /// mulberry32 — tiny, fast, plenty for game decisions.
  int nextInt(int max) {
    _seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _seed;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= t + _imul(t ^ (t >>> 7), t | 61);
    final result = (t ^ (t >>> 14)) & 0xFFFFFFFF;
    return result % max;
  }

  /// Fisher–Yates.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// Dart ints are 64-bit; mask to keep mulberry32's 32-bit wraparound.
  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
}
