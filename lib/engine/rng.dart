/// Deterministic 32-bit generator (mulberry32).
///
/// The whole state is one int, so a save file can store it and a reloaded
/// game continues with exactly the same rolls.
class Rng {
  Rng(int seed) : _state = seed & _mask;

  static const int _mask = 0xFFFFFFFF;

  int _state;

  int get state => _state;

  int nextU32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = ((t ^ (t >> 15)) * (t | 1)) & _mask;
    t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & _mask)) & _mask;
    return (t ^ (t >> 14)) & _mask;
  }

  /// Uniform in [0, 1).
  double nextDouble() => nextU32() / 4294967296.0;

  /// Uniform integer in [0, max).
  int nextInt(int max) => (nextDouble() * max).floor();

  /// Uniform in [lo, hi).
  double range(double lo, double hi) => lo + (hi - lo) * nextDouble();

  bool chance(double p) => nextDouble() < p;
}
