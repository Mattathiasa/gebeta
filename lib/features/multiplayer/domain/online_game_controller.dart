import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../game/domain/ai_engine.dart';
import '../../game/domain/game_controller.dart';
import '../../game/domain/game_engine.dart';
import '../data/room_repository.dart';
import '../domain/room.dart';

/// Everything the online game screen renders.
class OnlineGameState {
  const OnlineGameState({
    required this.code,
    required this.mySide,
    required this.board,
    required this.seq,
    this.room,
    this.phase = GameStatePhase.humanTurn,
    this.lastPit,
    this.error,
    this.validationFailed = false,
  });

  final String code;
  final Player mySide;
  final GebetaState board;
  final int seq;
  final Room? room;
  final GameStatePhase phase;
  final int? lastPit;

  /// One-shot error message for snackbar consumption.
  final String? error;

  /// Dual-compute rejected the opponent's move — the stream is no
  /// longer trusted and the screen should bail out.
  final bool validationFailed;

  bool get gameOver => board.isOver;
  bool get myTurn =>
      board.toMove == mySide && !gameOver && !validationFailed;

  /// Adapter for the shared board widget.
  GameState get boardState => GameState(
        board: board,
        difficulty: AiDifficulty.medium, // unused online
        phase: myTurn
            ? GameStatePhase.humanTurn
            : gameOver
                ? GameStatePhase.humanTurn
                : GameStatePhase.aiThinking,
        mySide: mySide,
        highlightedPit: null,
      );

  int? get result {
    if (!board.isOver) return null;
    final raw = board.result ?? 0;
    if (raw == 0) return 0;
    final winnerIsA = raw > 0;
    return (winnerIsA && mySide == Player.a) ||
            (!winnerIsA && mySide == Player.b)
        ? 1
        : -1;
  }

  OnlineGameState copyWith({
    Room? room,
    GebetaState? board,
    int? seq,
    GameStatePhase? phase,
    int? lastPit,
    String? error,
    bool clearError = false,
    bool? validationFailed,
  }) =>
      OnlineGameState(
        code: code,
        mySide: mySide,
        board: board ?? this.board,
        seq: seq ?? this.seq,
        room: room ?? this.room,
        phase: phase ?? this.phase,
        lastPit: lastPit ?? this.lastPit,
        error: clearError ? null : (error ?? this.error),
        validationFailed: validationFailed ?? this.validationFailed,
      );
}

final onlineGameStateProvider = AutoDisposeNotifierProviderFamily<
    OnlineGameController, OnlineGameState, String>(OnlineGameController.new);

class OnlineGameController
    extends AutoDisposeFamilyNotifier<OnlineGameState, String> {
  StreamSubscription<Room?>? _roomSub;
  StreamSubscription<RoomState?>? _stateSub;

  @override
  OnlineGameState build(String code) {
    final repo = ref.read(roomRepositoryProvider);
    final uid = ref.read(uidProvider).valueOrNull ?? 'unknown';

    // Side is known from the room; before the room arrives assume host
    // seat and correct on first room event.
    var initialSide = Player.a;

    _roomSub = repo.watchRoom(code).listen((room) {
      if (room == null) return;
      final sideLetter = room.sideOf(uid);
      final side = sideLetter == 'b' ? Player.b : Player.a;
      state = state.copyWith(room: room, board: _reseat(state.board, side));
      // Re-seat accessor: mutate mySide via a fresh state.
      state = _withSide(state, side);
    });

    _stateSub = repo.watchState(code).listen(_onState);

    ref.onDispose(() {
      _roomSub?.cancel();
      _stateSub?.cancel();
    });

    return OnlineGameState(
      code: code,
      mySide: initialSide,
      board: GebetaState.initial(),
      seq: 0,
    );
  }

  OnlineGameState _withSide(OnlineGameState s, Player side) => OnlineGameState(
        code: s.code,
        mySide: side,
        board: s.board,
        seq: s.seq,
        room: s.room,
        phase: s.phase,
        lastPit: s.lastPit,
        error: s.error,
        validationFailed: s.validationFailed,
      );

  GebetaState _reseat(GebetaState board, Player side) {
    // Board engine state is side-agnostic (absolute indices) — the
    // seat only affects presentation, so nothing to rewrite.
    return board;
  }

  void _onState(RoomState? roomState) {
    if (roomState == null) return;
    final incoming = roomState.toEngine();

    // --- dual-compute validation --------------------------------------
    // No server runtime in this project (free tier, no Functions), so
    // every client re-derives the position: apply the named pit to its
    // own copy of the previous state and require an exact match.
    // Only checkable when exactly one move landed (seq == prev + 1);
    // RTDB streams deliver full snapshots, so a bigger jump means we
    // missed events — accept the snapshot and resync rather than
    // false-flag the opponent.
    final prevSeq = state.seq;
    if (roomState.seq == prevSeq + 1 && roomState.lastPit != null) {
      final expected = roomState.lastPit == -1
          ? state.board.pass()
          : state.board.legalMoves().contains(roomState.lastPit)
              ? state.board.apply(roomState.lastPit!)
              : null;
      if (expected != null && !_samePosition(expected, incoming)) {
        state = state.copyWith(validationFailed: true);
        return;
      }
    }

    state = state.copyWith(
      board: incoming,
      seq: roomState.seq,
      lastPit: roomState.lastPit,
      phase: incoming.isOver
          ? GameStatePhase.humanTurn
          : incoming.toMove == state.mySide
              ? GameStatePhase.humanTurn
              : GameStatePhase.aiThinking,
    );
  }

  bool _samePosition(GebetaState a, GebetaState b) =>
      a.scoreA == b.scoreA &&
      a.scoreB == b.scoreB &&
      a.toMove == b.toMove &&
      a.passes == b.passes &&
      a.quietPlies == b.quietPlies &&
      a.pits.length == b.pits.length &&
      List.generate(12, (i) => a.pits[i] == b.pits[i]).every((x) => x);

  Future<void> submitPit(int pit) async {
    if (!state.myTurn) return;
    final repo = ref.read(roomRepositoryProvider);
    final uid = await ref.read(uidProvider.future);
    final outcome = await repo.submitMove(
      code: arg,
      uid: uid,
      pit: pit,
    );
    if (outcome != MoveOutcome.accepted) {
      state = state.copyWith(
        error: switch (outcome) {
          MoveOutcome.notYourTurn => 'Not your turn',
          MoveOutcome.invalidMove => 'Illegal move',
          MoveOutcome.stale => 'Board out of sync — rejoining…',
          MoveOutcome.accepted => '',
        },
      );
      if (outcome == MoveOutcome.stale) {
        // Force a full refresh on next stream event.
        state = state.copyWith(seq: -1, clearError: true);
      }
    }
  }

  Future<void> leave() async {
    final repo = ref.read(roomRepositoryProvider);
    final uid = await ref.read(uidProvider.future);
    await repo.leaveRoom(code: arg, uid: uid);
  }
}
