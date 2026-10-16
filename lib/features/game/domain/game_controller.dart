import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/seeded_rng.dart';
import '../../stats/data/stats_store.dart';
import '../../stats/domain/stats_providers.dart';
import 'ai_engine.dart';
import 'game_engine.dart';

/// Everything the UI needs to render one frame of a match.
class GameState {
  const GameState({
    required this.board,
    required this.difficulty,
    this.phase = GameStatePhase.humanTurn,
    this.mySide = Player.a,
    this.highlightedPit,
    this.captureFlash = const [],
    this.matchWins = 0,
    this.matchLosses = 0,
    this.result,
    this.stats = const PlayerStats(),
  });

  final GebetaState board;
  final AiDifficulty difficulty;
  final GameStatePhase phase;

  /// Which seat "you" sit in. AI matches always play Player.a; online
  /// games may seat you at Player.b, which flips the board.
  final Player mySide;

  /// Pit currently lit by the sow animation (one seed at a time).
  final int? highlightedPit;

  /// Pits that just vanished into a capture pile — flashed briefly.
  final List<int> captureFlash;

  final int matchWins;
  final int matchLosses;

  /// 1 = human won, -1 = human lost, 0 = draw. Null while in progress.
  final int? result;

  final PlayerStats stats;

  bool get gameOver => result != null;

  bool get humanCanTap =>
      phase == GameStatePhase.humanTurn &&
      board.toMove == mySide &&
      !gameOver;

  GameState copyWith({
    GebetaState? board,
    AiDifficulty? difficulty,
    GameStatePhase? phase,
    Player? mySide,
    int? highlightedPit,
    List<int>? captureFlash,
    int? matchWins,
    int? matchLosses,
    int? result,
    PlayerStats? stats,
    bool clearHighlight = false,
    bool clearResult = false,
  }) =>
      GameState(
        board: board ?? this.board,
        difficulty: difficulty ?? this.difficulty,
        phase: phase ?? this.phase,
        mySide: mySide ?? this.mySide,
        highlightedPit: clearHighlight ? null : (highlightedPit ?? this.highlightedPit),
        captureFlash: captureFlash ?? this.captureFlash,
        matchWins: matchWins ?? this.matchWins,
        matchLosses: matchLosses ?? this.matchLosses,
        result: clearResult ? null : (result ?? this.result),
        stats: stats ?? this.stats,
      );
}

enum GameStatePhase { humanTurn, animating, aiThinking }

final gameStateProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  static const _seedMs = 85; // per-seed sow animation step
  static const _aiThinkDelayMs = 350;

  /// Tests crank this to 0 so a full match runs in milliseconds.
  static double debugDelayScale = 1.0;

  final _rng = SeededRng.fromNow();
  var _busy = false;

  Duration _scaled(int ms) =>
      Duration(milliseconds: (ms * debugDelayScale).round());

  @override
  GameState build() {
    final board = GebetaState.initial();
    return GameState(board: board, difficulty: AiDifficulty.medium);
  }

  /// Starts a fresh match. The starter is randomized so rematch night
  /// doesn't always deal the same first move.
  Future<void> newGame({AiDifficulty? difficulty}) async {
    final d = difficulty ?? state.difficulty;
    final starter = Player.values[_rng.nextInt(2)];
    final board = GebetaState.initial(starter: starter);
    state = GameState(
      board: board,
      difficulty: d,
      matchWins: state.matchWins,
      matchLosses: state.matchLosses,
      stats: state.stats,
    );
    await _advanceTurn();
  }

  void setDifficulty(AiDifficulty d) {
    state = state.copyWith(difficulty: d);
  }

  /// Human tapped [pit].
  Future<void> tapPit(int pit) async {
    if (_busy || !state.humanCanTap) return;
    if (!state.board.legalMoves().contains(pit)) return;
    await _playMove(pit);
  }

  Future<void> _playMove(int pit) async {
    _busy = true;
    try {
      final board = state.board;

      // 1. Light each sow step so the eye can follow the seeds.
      state = state.copyWith(
        phase: GameStatePhase.animating,
        captureFlash: const [],
      );
      for (final idx in board.sowPath(pit)) {
        state = state.copyWith(highlightedPit: idx);
        await Future<void>.delayed(_scaled(_seedMs));
      }

      // 2. Commit — engine validates and captures.
      final next = board.apply(pit);
      final emptied = [
        for (var i = 0; i < 12; i++)
          if (board.pits[i] > 0 && next.pits[i] == 0) i,
      ];
      state = state.copyWith(
        board: next,
        clearHighlight: true,
        captureFlash: emptied,
      );
      if (emptied.isNotEmpty) {
        await Future<void>.delayed(_scaled(280));
        state = state.copyWith(captureFlash: const []);
      }

      if (await _checkEnd()) return;
      await _advanceTurn();
    } finally {
      _busy = false;
    }
  }

  /// Resolves forced passes for whichever side is stuck, then runs the
  /// AI if it is the opponent's turn.
  Future<void> _advanceTurn() async {
    if (state.gameOver) return;

    // Pass loop — either side may be stuck.
    var guard = 0;
    while (state.board.legalMoves().isEmpty && guard < 4) {
      final passed = state.board.pass();
      state = state.copyWith(board: passed);
      if (await _checkEnd()) return;
      guard++;
    }

    if (state.board.toMove != Player.b) {
      state = state.copyWith(phase: GameStatePhase.humanTurn);
      return;
    }

    state = state.copyWith(phase: GameStatePhase.aiThinking);
    await Future<void>.delayed(_scaled(_aiThinkDelayMs));

    final move = await _chooseAiMove();
    if (move == null) {
      // AI has no move after all — treat as pass and re-resolve.
      if (state.board.legalMoves().isEmpty) {
        state = state.copyWith(board: state.board.pass());
        if (await _checkEnd()) return;
      }
      state = state.copyWith(phase: GameStatePhase.humanTurn);
      return;
    }
    await _playMove(move);
  }

  /// Hard searches can take ~1s — run it off the UI thread.
  Future<int?> _chooseAiMove() async {
    final board = state.board;
    final difficulty = state.difficulty;
    if (difficulty != AiDifficulty.hard) {
      return GebetaAi(difficulty: difficulty, rng: _rng).chooseMove(board);
    }
    return compute(_aiHardEntry, _AiJob(
      pits: List.of(board.pits),
      scoreA: board.scoreA,
      scoreB: board.scoreB,
      toMoveIsA: board.toMove == Player.a,
      quietPlies: board.quietPlies,
      passes: board.passes,
      seed: _rng.nextInt(0x7fffffff),
    ));
  }

  Future<bool> _checkEnd() async {
    if (!state.board.isOver) {
      state = state.copyWith(phase: GameStatePhase.humanTurn);
      return false;
    }
    final result = state.board.result ?? 0;
    final stats = await StatsStore.record(result: result);
    ref.invalidate(playerStatsProvider);
    state = state.copyWith(
      result: result,
      stats: stats,
      matchWins: state.matchWins + (result > 0 ? 1 : 0),
      matchLosses: state.matchLosses + (result < 0 ? 1 : 0),
      phase: GameStatePhase.humanTurn,
    );
    return true;
  }
}

/// Isolate payload — [GebetaState] isn't sendable as a live object graph
/// we want to freeze, so the fields travel as plain data.
class _AiJob {
  const _AiJob({
    required this.pits,
    required this.scoreA,
    required this.scoreB,
    required this.toMoveIsA,
    required this.quietPlies,
    required this.passes,
    required this.seed,
  });

  final List<int> pits;
  final int scoreA;
  final int scoreB;
  final bool toMoveIsA;
  final int quietPlies;
  final int passes;
  final int seed;
}

@pragma('vm:entry-point')
int? _aiHardEntry(_AiJob job) {
  final state = GebetaState(
    pits: job.pits,
    scoreA: job.scoreA,
    scoreB: job.scoreB,
    toMove: job.toMoveIsA ? Player.a : Player.b,
    quietPlies: job.quietPlies,
    passes: job.passes,
  );
  return GebetaAi(
    difficulty: AiDifficulty.hard,
    rng: SeededRng(job.seed),
  ).chooseMove(state);
}
