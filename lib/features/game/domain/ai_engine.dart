import '../../../core/utils/seeded_rng.dart';
import 'game_engine.dart';

/// How the computer picks moves.
enum AiDifficulty { easy, medium, hard }

/// Minimax with alpha-beta pruning over [GebetaState].
///
/// The state space is tiny (12 pits, ≤48 seeds), so even depth 6 runs
/// comfortably under a second on a phone. [hard] uses iterative
/// deepening against a wall-clock budget so slow devices degrade
/// gracefully instead of freezing a turn.
class GebetaAi {
  GebetaAi({required this.difficulty, SeededRng? rng})
      : _rng = rng ?? SeededRng.fromNow();

  final AiDifficulty difficulty;
  final SeededRng _rng;

  static const _hardBudgetMs = 900;
  static const _hardMaxDepth = 8;

  /// Picks a move for [state]'s side to move. Returns null if the game
  /// is over or the player must pass.
  int? chooseMove(GebetaState state) {
    final moves = state.legalMoves();
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first;

    switch (difficulty) {
      case AiDifficulty.easy:
        return _chooseEasy(state, moves);
      case AiDifficulty.medium:
        return _minimaxRoot(state, moves, depth: 2);
      case AiDifficulty.hard:
        return _chooseHard(state, moves);
    }
  }

  /// Roughly 70% random, 30% takes a capture if one exists — beats
  /// beginners occasionally without ever feeling psychic.
  int? _chooseEasy(GebetaState state, List<int> moves) {
    final capturing = moves
        .where((m) => _capturedSeeds(state, m) > 0)
        .toList(growable: false);
    if (capturing.isNotEmpty && _rng.nextInt(10) < 3) {
      return capturing[_rng.nextInt(capturing.length)];
    }
    return moves[_rng.nextInt(moves.length)];
  }

  int _chooseHard(GebetaState state, List<int> moves) {
    final clock = Stopwatch()..start();
    var best = moves.first;
    for (var depth = 2; depth <= _hardMaxDepth; depth++) {
      final completed = _minimaxRoot(state, moves, depth: depth, budget: clock);
      // A depth that ran out of budget partway through is incomplete —
      // keep the previous complete answer instead of a partial one.
      if (completed != null) best = completed;
      if (clock.elapsedMilliseconds >= _hardBudgetMs) break;
    }
    return best;
  }

  /// Root of the search. Returns the best move if the whole depth was
  /// searched within [budget], or null if the budget cut it short.
  int? _minimaxRoot(
    GebetaState state,
    List<int> moves, {
    required int depth,
    Stopwatch? budget,
  }) {
    // Captures first: alpha-beta prunes far better with good ordering.
    final ordered = _orderMoves(state, moves);
    var bestMove = ordered.first;
    var bestScore = -0x7fffffff;
    var alpha = -0x7fffffff;
    const beta = 0x7fffffff;

    for (final move in ordered) {
      if (budget != null && budget.elapsedMilliseconds > _hardBudgetMs) {
        return null; // incomplete
      }
      final score = _minimax(
        state.apply(move),
        depth - 1,
        alpha,
        beta,
        budget,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      if (score > alpha) alpha = score;
    }
    return bestMove;
  }

  /// Returns the minimax value of [state] from [state.toMove]'s
  /// perspective (positive = good for whoever is about to move).
  int _minimax(
    GebetaState state,
    int depth,
    int alpha,
    int beta,
    Stopwatch? budget,
  ) {
    if (state.isOver) {
      // Terminal: result is from Player.a's perspective; flip for the
      // side to move. Big magnitude so wins dominate heuristics.
      final result = state.result ?? 0;
      final forMover = state.toMove == Player.a ? result : -result;
      return forMover * 100000;
    }

    final moves = state.legalMoves();
    if (moves.isEmpty) {
      return _passNode(state, depth, alpha, beta, budget);
    }
    if (depth == 0) return _evaluate(state);

    final ordered = _orderMoves(state, moves);
    final maximizing = true; // always the mover's turn in this recursion

    var best = -0x7fffffff;
    for (final move in ordered) {
      if (budget != null && budget.elapsedMilliseconds > _hardBudgetMs) {
        break;
      }
      final score = _minimax(
        state.apply(move),
        depth - 1,
        alpha,
        beta,
        budget,
      );
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (beta <= alpha) break; // prune
      assert(maximizing);
    }
    return best;
  }

  /// A forced pass: flip the turn and search one ply deeper (passing
  /// itself carries no information, so we don't burn a depth level).
  int _passNode(
    GebetaState state,
    int depth,
    int alpha,
    int beta,
    Stopwatch? budget,
  ) {
    final passed = state.pass();
    if (passed.isOver) {
      final result = passed.result ?? 0;
      final forMover = state.toMove == Player.a ? result : -result;
      return forMover * 100000;
    }
    return _minimax(passed, depth, alpha, beta, budget);
  }

  /// Heuristic, from the side-to-move's perspective.
  /// Material leads; a small mobility term breaks equal-material ties.
  int _evaluate(GebetaState state) {
    final material = state.scoreA - state.scoreB;
    final forMover = state.toMove == Player.a ? material : -material;
    final mobility =
        state.seedsInRow(state.toMove) - state.seedsInRow(opponentOf(state.toMove));
    return forMover * 100 + (state.toMove == Player.a ? mobility : -mobility);
  }

  List<int> _orderMoves(GebetaState state, List<int> moves) {
    final scored = <({int move, int gain})>[
      for (final m in moves) (move: m, gain: _capturedSeeds(state, m)),
    ];
    scored.sort((a, b) => b.gain.compareTo(a.gain));
    return [for (final s in scored) s.move];
  }

  /// Capture gain of [move] — used only for ordering and the easy bot,
  /// computed by applying on a copy (cheap at this state size).
  int _capturedSeeds(GebetaState state, int move) {
    final next = state.apply(move);
    final me = state.toMove;
    return next.scoreOf(me) - state.scoreOf(me);
  }
}
