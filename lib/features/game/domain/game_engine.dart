/// Pure-Dart Gebeta (Ethiopian mancala) engine.
///
/// No Flutter imports — this file must run identically in tests, in the
/// app, and (as the reference for a future TypeScript mirror) on a server.
///
/// Ruleset: "classic" Oware-lineage, the widely played 12-pit / 4-seed
/// configuration. See docs/RULESETS.md — regional variants exist and this
/// file is the single place a variant would be swapped.
///
/// Board layout (index order = sowing direction, wrapping 11 → 0):
///
///        opponent (North / Player.b)
///   pits 11 10  9  8  7  6
///   pits  0  1  2  3  4  5
///        you (South / Player.a)
///
/// Player.a owns 0–5, Player.b owns 6–11. Captures go to side piles
/// (there are no end stores on this board).
library;

enum Player { a, b }

Player opponentOf(Player p) => p == Player.a ? Player.b : Player.a;

/// Immutable position. Never mutated — [apply] and [pass] return new
/// states, which keeps the AI search tree safe to share freely.
class GebetaState {
  GebetaState({
    required this.pits,
    required this.scoreA,
    required this.scoreB,
    required this.toMove,
    this.passes = 0,
    this.quietPlies = 0,
  }) : assert(pits.length == 12);

  /// 12 pit counts. Indices 0–5 = Player.a, 6–11 = Player.b.
  final List<int> pits;

  final int scoreA;
  final int scoreB;

  final Player toMove;

  /// Consecutive passes (a player with no legal move must pass).
  /// Two in a row = board frozen = game over.
  final int passes;

  /// Plies since the last capture. Random and careless play can cycle
  /// the same seeds around the board forever; digital Oware caps this
  /// so every game ends. When [maxQuietPlies] is reached the scores
  /// stand as-is.
  final int quietPlies;

  static const seedsPerPit = 4;
  static const totalSeeds = 48;
  static const winThreshold = 24; // strictly more than 24 of 48 wins
  static const maxQuietPlies = 50;

  /// Standard opening; [starter] decides who moves first (callers
  /// randomize via SeededRng so rematches aren't always the same hand).
  factory GebetaState.initial({Player starter = Player.a}) {
    return GebetaState(
      pits: List.filled(12, seedsPerPit),
      scoreA: 0,
      scoreB: 0,
      toMove: starter,
    );
  }

  static Player ownerOf(int index) => index < 6 ? Player.a : Player.b;

  int operator [](int index) => pits[index];

  int seedsInRow(Player player) {
    final start = player == Player.a ? 0 : 6;
    var sum = 0;
    for (var i = start; i < start + 6; i++) {
      sum += pits[i];
    }
    return sum;
  }

  int scoreOf(Player player) => player == Player.a ? scoreA : scoreB;

  bool get isOver => passes >= 2 || quietPlies >= maxQuietPlies;

  /// null while in progress; 1 = Player.a wins, -1 = Player.b wins,
  /// 0 = draw. Meaningful only once [isOver].
  int? get result {
    if (!isOver) return null;
    if (scoreA > winThreshold) return 1;
    if (scoreB > winThreshold) return -1;
    return 0;
  }

  /// Legal pit indices for [toMove], starvation rules applied:
  ///
  /// - Sow only from your own non-empty pit.
  /// - A move that leaves the opponent with zero seeds *after captures*
  ///   is illegal — unless every move does, in which case it is forced.
  /// - If the opponent is already empty you must give them seeds: a
  ///   move that never reaches their row is illegal.
  List<int> legalMoves() {
    if (isOver) return const [];

    final start = toMove == Player.a ? 0 : 6;
    final candidates = <int>[
      for (var i = start; i < start + 6; i++)
        if (pits[i] > 0) i,
    ];
    if (candidates.isEmpty) return const [];

    final opp = opponentOf(toMove);
    final oppBefore = seedsInRow(opp);

    // Starvation is a *post-capture* property: sowing only adds seeds,
    // captures remove them. So each candidate is checked against the
    // fully advanced position, not just the sow.
    final keepsOppAlive = <int>[
      for (final move in candidates)
        if (_advance(move).seedsInRow(opp) > 0) move,
    ];

    if (oppBefore == 0) {
      // Must give seeds; if no move can, the board is dead — allow any.
      return keepsOppAlive.isEmpty ? candidates : keepsOppAlive;
    }
    // If every move would starve the opponent, the starve is forced.
    return keepsOppAlive.isEmpty ? candidates : keepsOppAlive;
  }

  /// Applies [move] without checking legality. Core rules only:
  /// sow (skipping the origin on a full lap), then capture chain.
  GebetaState _advance(int move) {
    final pits = List<int>.from(this.pits);
    var scoreA = this.scoreA;
    var scoreB = this.scoreB;
    final me = toMove;

    // --- sow -----------------------------------------------------------
    var seeds = pits[move];
    pits[move] = 0;
    var idx = move;
    while (seeds > 0) {
      idx = (idx + 1) % 12;
      // On a full lap, skip the origin pit — you don't drop back into
      // the hole you lifted from.
      if (idx == move) continue;
      pits[idx]++;
      seeds--;
    }

    // --- capture -------------------------------------------------------
    // Rule 1: the last seed landed in the opponent's row and that pit
    // holds 2 or 3 → take it and continue backward (against the sow
    // direction) while pits keep holding 2 or 3. Walking backward from
    // the last sown pit only ever visits pits sown this turn (the walk
    // ends at the emptied origin, which is the mover's own row), so no
    // extra "was it sown?" bookkeeping is needed.
    var captured = 0;
    var cursor = idx;
    var captureHappened = false;
    while (true) {
      final owner = GebetaState.ownerOf(cursor);
      if (owner != me && (pits[cursor] == 2 || pits[cursor] == 3)) {
        captured += pits[cursor];
        pits[cursor] = 0;
        captureHappened = true;
        cursor = (cursor + 11) % 12; // one step backward
      } else {
        break;
      }
    }
    // Rule 2 ("no capture" fallback): nothing was taken from the
    // opponent and the last pit is your own with 2 or 3 → take it.
    if (!captureHappened &&
        GebetaState.ownerOf(cursor) == me &&
        (pits[cursor] == 2 || pits[cursor] == 3)) {
      captured += pits[cursor];
      pits[cursor] = 0;
    }

    if (me == Player.a) {
      scoreA += captured;
    } else {
      scoreB += captured;
    }

    return GebetaState(
      pits: pits,
      scoreA: scoreA,
      scoreB: scoreB,
      toMove: opponentOf(me),
      passes: 0,
      quietPlies: captured > 0 ? 0 : quietPlies + 1,
    );
  }

  /// The exact pit indices a sow from [move] drops into, in order.
  /// Used by the UI to animate the move before committing it.
  List<int> sowPath(int move) {
    final seeds = pits[move];
    final path = <int>[];
    var idx = move;
    var placed = 0;
    while (placed < seeds) {
      idx = (idx + 1) % 12;
      if (idx == move) continue;
      path.add(idx);
      placed++;
    }
    return path;
  }

  /// Applies [move] (must be in [legalMoves]) and returns the next
  /// position with [toMove] flipped. Throws [ArgumentError] otherwise.
  GebetaState apply(int move) {
    if (!legalMoves().contains(move)) {
      throw ArgumentError.value(move, 'move', 'not a legal move');
    }
    return _advance(move);
  }

  /// The player to move has no legal pit — hand the turn back. Throws
  /// if they actually can move (callers must check first).
  GebetaState pass() {
    if (legalMoves().isNotEmpty) {
      throw StateError('player can still move; pass() is illegal');
    }
    return GebetaState(
      pits: pits,
      scoreA: scoreA,
      scoreB: scoreB,
      toMove: opponentOf(toMove),
      passes: passes + 1,
      quietPlies: quietPlies + 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GebetaState &&
      _listEquals(other.pits, pits) &&
      other.scoreA == scoreA &&
      other.scoreB == scoreB &&
      other.toMove == toMove &&
      other.passes == passes &&
      other.quietPlies == quietPlies;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(pits),
        scoreA,
        scoreB,
        toMove,
        passes,
        quietPlies,
      );

  @override
  String toString() =>
      'GebetaState(${pits.join(',')} | $scoreA–$scoreB | $toMove | pass $passes)';
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
