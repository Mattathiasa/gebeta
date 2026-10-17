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

  static const _hardBudgetMs = 1200;
  static const _hardMaxDepth = 12;

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
        return _minimaxRoot(state, moves, depth: 4);
      case AiDifficulty.hard:
        return _chooseHard(state, moves);
    }
  }

  /// Takes its biggest capture half the time, and half the time steers
  /// away from moves that hand the opponent an immediate big capture —
  /// but still plays randomly often enough to lose to beginners.
  int? _chooseEasy(GebetaState state, List<int> moves) {
    final capturing = moves
        .where((m) => _capturedSeeds(state, m) > 0)
        .toList(growable: false);
    if (capturing.isNotEmpty && _rng.nextInt(10) < 5) {
      capturing.sort(
        (a, b) => _capturedSeeds(state, b).compareTo(_capturedSeeds(state, a)),
      );
      return capturing.first;
    }

    if (_rng.nextInt(10) < 5) {
      final safe = moves
          .where((m) => _opponentBestReply(state, m) < 3)
          .toList(growable: false);
      if (safe.isNotEmpty) return safe[_rng.nextInt(safe.length)];
    }
    return moves[_rng.nextInt(moves.length)];
  }

  /// The opponent's best immediate capture after [move] — a cheap 1-ply
  /// check so easy avoids the most obvious blunders without searching.
  int _opponentBestReply(GebetaState state, int move) {
    final next = state.apply(move);
    var best = 0;
    for (final reply in next.legalMoves()) {
      final gain = _capturedSeeds(next, reply);
      if (gain > best) best = gain;
    }
    return best;
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
      // Negamax: the child is scored from the opponent's perspective, so
      // negate it to get its value from ours.
      final score = -_minimax(
        state.apply(move),
        depth - 1,
        -beta,
        -alpha,
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

    var best = -0x7fffffff;
    for (final move in ordered) {
      if (budget != null && budget.elapsedMilliseconds > _hardBudgetMs) {
        break;
      }
      // Negamax: negate the child (opponent's-perspective) score to get
      // its value from this node's mover's perspective.
      final score = -_minimax(
        state.apply(move),
        depth - 1,
        -beta,
        -alpha,
        budget,
      );
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break; // prune
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
    // passed.toMove is the opponent; negate back to state.toMove's view.
    return -_minimax(passed, depth, -beta, -alpha, budget);
  }

  /// Heuristic, from the side-to-move's perspective. Material leads by a
  /// wide margin; mobility and exposed pits break near-ties and steer the
  /// search away from handing the opponent a free capture.
  int _evaluate(GebetaState state) {
    final mover = state.toMove;
    final opp = opponentOf(mover);

    final material = state.scoreOf(mover) - state.scoreOf(opp);
    final mobility = state.seedsInRow(mover) - state.seedsInRow(opp);
    final exposure = _exposedPits(state, opp) - _exposedPits(state, mover);

    return material * 100 + mobility + exposure * 6;
  }

  /// Pits sitting at 1 or 2 seeds are one sow away from holding 2 or 3 —
  /// i.e. one move from being capturable.
  int _exposedPits(GebetaState state, Player player) {
    final start = player == Player.a ? 0 : 6;
    var count = 0;
    for (var i = start; i < start + 6; i++) {
      if (state.pits[i] == 1 || state.pits[i] == 2) count++;
    }
    return count;
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
