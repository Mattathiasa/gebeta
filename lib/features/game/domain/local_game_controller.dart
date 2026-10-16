import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/seeded_rng.dart';
import 'ai_engine.dart';
import 'game_controller.dart';
import 'game_engine.dart';

/// Two humans, one device. No AI, no network — just the engine and a
/// hand-off beat between turns.
class LocalGameState {
  const LocalGameState({
    required this.board,
    this.phase = GameStatePhase.humanTurn,
    this.highlightedPit,
    this.captureFlash = const [],
    this.winsA = 0,
    this.winsB = 0,
    this.draws = 0,
  });

  final GebetaState board;
  final GameStatePhase phase;
  final int? highlightedPit;
  final List<int> captureFlash;
  final int winsA;
  final int winsB;
  final int draws;

  bool get gameOver => board.isOver;

  /// Adapter for the shared board widget: "mySide" tracks whoever's
  /// turn it is, since both players share one screen and the board
  /// flips each turn so the mover's row always reads as the bottom row
  /// (the same "pass the phone" convention other pass-and-play games
  /// use) — see [GebetaBoard].
  GameState get boardState => GameState(
        board: board,
        difficulty: AiDifficulty.medium, // unused locally
        phase: phase,
        mySide: board.toMove,
        highlightedPit: highlightedPit,
        captureFlash: captureFlash,
      );

  LocalGameState copyWith({
    GebetaState? board,
    GameStatePhase? phase,
    int? highlightedPit,
    List<int>? captureFlash,
    int? winsA,
    int? winsB,
    int? draws,
    bool clearHighlight = false,
  }) =>
      LocalGameState(
        board: board ?? this.board,
        phase: phase ?? this.phase,
        highlightedPit:
            clearHighlight ? null : (highlightedPit ?? this.highlightedPit),
        captureFlash: captureFlash ?? this.captureFlash,
        winsA: winsA ?? this.winsA,
        winsB: winsB ?? this.winsB,
        draws: draws ?? this.draws,
      );
}

final localGameStateProvider =
    NotifierProvider<LocalGameController, LocalGameState>(
        LocalGameController.new);

class LocalGameController extends Notifier<LocalGameState> {
  static const _seedMs = 85;

  /// Tests crank this to 0 so a full match runs in milliseconds.
  static double debugDelayScale = 1.0;

  final _rng = SeededRng.fromNow();
  var _busy = false;

  Duration _scaled(int ms) =>
      Duration(milliseconds: (ms * debugDelayScale).round());

  @override
  LocalGameState build() => LocalGameState(board: GebetaState.initial());

  /// Starts a fresh match, keeping the running score. The starter is
  /// randomized so the same player doesn't always open.
  void newGame() {
    final starter = Player.values[_rng.nextInt(2)];
    state = LocalGameState(
      board: GebetaState.initial(starter: starter),
      winsA: state.winsA,
      winsB: state.winsB,
      draws: state.draws,
    );
  }

  Future<void> tapPit(int pit) async {
    if (_busy || !state.boardState.humanCanTap) return;
    if (!state.board.legalMoves().contains(pit)) return;
    await _playMove(pit);
  }

  Future<void> _playMove(int pit) async {
    _busy = true;
    try {
      final board = state.board;

      state = state.copyWith(
        phase: GameStatePhase.animating,
        captureFlash: const [],
      );
      for (final idx in board.sowPath(pit)) {
        state = state.copyWith(highlightedPit: idx);
        await Future<void>.delayed(_scaled(_seedMs));
      }

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

      _resolvePasses();
      _checkEnd();
    } finally {
      _busy = false;
    }
  }

  /// Resolves forced passes for whichever side is stuck — no AI turn to
  /// trigger afterward, just hand the screen back to whoever can move.
  void _resolvePasses() {
    var guard = 0;
    while (!state.board.isOver &&
        state.board.legalMoves().isEmpty &&
        guard < 4) {
      state = state.copyWith(board: state.board.pass());
      guard++;
    }
  }

  void _checkEnd() {
    if (!state.board.isOver) {
      state = state.copyWith(phase: GameStatePhase.humanTurn);
      return;
    }
    final result = state.board.result ?? 0;
    state = state.copyWith(
      phase: GameStatePhase.humanTurn,
      winsA: state.winsA + (result > 0 ? 1 : 0),
      winsB: state.winsB + (result < 0 ? 1 : 0),
      draws: state.draws + (result == 0 ? 1 : 0),
    );
  }
}
