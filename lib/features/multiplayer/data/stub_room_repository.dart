import 'dart:async';

import '../../game/domain/game_engine.dart';
import '../domain/room.dart';
import 'room_repository.dart';

/// In-memory room backend for development and tests. Mirrors the RTDB
/// implementation's contract exactly — including the turn + legality
/// checks — so the online controller behaves identically either way.
class StubRoomRepository implements RoomRepository {
  final _rooms = <String, Room>{};
  final _states = <String, RoomState>{};
  final _roomControllers = <String, StreamController<Room?>>{};
  final _stateControllers = <String, StreamController<RoomState?>>{};

  @override
  Future<String> createRoom({required String uid}) async {
    var code = generateRoomCode();
    while (_rooms.containsKey(code)) {
      code = generateRoomCode();
    }
    final room = Room(code: code, hostId: uid, starterIsA: true);
    _rooms[code] = room;
    _states[code] = RoomState.initial(GebetaState.initial(), starterIsA: true);
    _emitRoom(code);
    _emitState(code);
    return code;
  }

  @override
  Future<Room> joinRoom({required String code, required String uid}) async {
    final room = _rooms[code];
    if (room == null) {
      throw const RoomException(RoomExceptionType.notFound);
    }
    if (room.isFull) {
      throw const RoomException(RoomExceptionType.full);
    }
    final joined = room.copyWith(guestId: uid, status: RoomStatus.playing);
    _rooms[code] = joined;
    _emitRoom(code);
    return joined;
  }

  @override
  Stream<Room?> watchRoom(String code) {
    final controller = _roomControllers.putIfAbsent(
      code,
      () => StreamController<Room?>.broadcast(),
    );
    // Emit current value on listen (broadcast streams don't replay).
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(_rooms[code]);
    });
    return controller.stream;
  }

  @override
  Stream<RoomState?> watchState(String code) {
    final controller = _stateControllers.putIfAbsent(
      code,
      () => StreamController<RoomState?>.broadcast(),
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(_states[code]);
    });
    return controller.stream;
  }

  @override
  Future<MoveOutcome> submitMove({
    required String code,
    required String uid,
    required int pit,
  }) async {
    final room = _rooms[code];
    final state = _states[code];
    if (room == null || state == null) return MoveOutcome.stale;

    final engine = state.toEngine();
    final side = room.sideOf(uid);
    final expectedLetter = state.toMoveIsA ? 'a' : 'b';
    if (side != expectedLetter) return MoveOutcome.notYourTurn;

    // pit == -1 means "I have no legal move — pass".
    if (pit == -1) {
      if (engine.legalMoves().isNotEmpty) return MoveOutcome.invalidMove;
      final passed = engine.pass();
      _states[code] = RoomState(
        pits: List.of(passed.pits),
        scoreA: passed.scoreA,
        scoreB: passed.scoreB,
        toMoveIsA: passed.toMove == Player.a,
        passes: passed.passes,
        quietPlies: passed.quietPlies,
        seq: state.seq + 1,
        lastPit: -1,
        lastBy: uid,
      );
      if (passed.isOver) {
        _rooms[code] = room.copyWith(status: RoomStatus.finished);
        _emitRoom(code);
      }
      _emitState(code);
      return MoveOutcome.accepted;
    }

    if (!engine.legalMoves().contains(pit)) return MoveOutcome.invalidMove;

    final next = engine.apply(pit);
    _states[code] = RoomState(
      pits: List.of(next.pits),
      scoreA: next.scoreA,
      scoreB: next.scoreB,
      toMoveIsA: next.toMove == Player.a,
      passes: next.passes,
      quietPlies: next.quietPlies,
      seq: state.seq + 1,
      lastPit: pit,
      lastBy: uid,
    );
    if (next.isOver) {
      _rooms[code] = room.copyWith(status: RoomStatus.finished);
      _emitRoom(code);
    }
    _emitState(code);
    return MoveOutcome.accepted;
  }

  @override
  Future<void> leaveRoom({required String code, required String uid}) async {
    final room = _rooms[code];
    if (room == null) return;
    if (uid == room.hostId) {
      _rooms.remove(code);
      _states.remove(code);
      _emitRoom(code);
      _emitState(code);
    } else if (uid == room.guestId) {
      final left = room.copyWith();
      _rooms[code] = Room(
        code: left.code,
        hostId: left.hostId,
        status: RoomStatus.lobby,
        starterIsA: left.starterIsA,
      );
      _emitRoom(code);
    }
  }

  @override
  void dispose() {
    for (final c in _roomControllers.values) {
      c.close();
    }
    for (final c in _stateControllers.values) {
      c.close();
    }
  }

  void _emitRoom(String code) {
    _roomControllers[code]?.add(_rooms[code]);
  }

  void _emitState(String code) {
    _stateControllers[code]?.add(_states[code]);
  }
}
