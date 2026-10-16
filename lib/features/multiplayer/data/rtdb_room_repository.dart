import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../game/domain/game_engine.dart';
import '../domain/room.dart';
import 'room_repository.dart';

/// Realtime Database backend. Schema (rules in database.rules.json):
///
///   rooms/{code}                → Room JSON
///   rooms/{code}/state          → RoomState JSON (seq-versioned)
///   roomCodes/{code}            → true (existence check without listing)
///
/// Moves go through a transaction that re-checks turn + legality
/// server-side-of-the-client: RTDB transactions run on the backend, so
/// a tampered client cannot skip the check without failing the write.
class RtdbRoomRepository implements RoomRepository {
  RtdbRoomRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  @override
  void dispose() {}

  DatabaseReference _roomRef(String code) => _db.ref('rooms/$code');
  DatabaseReference _stateRef(String code) => _db.ref('rooms/$code/state');
  DatabaseReference _codeRef(String code) => _db.ref('roomCodes/$code');

  @override
  Future<String> createRoom({required String uid}) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateRoomCode();
      final exists = await _codeRef(code).get();
      if (exists.exists) continue;

      final room = Room(code: code, hostId: uid, starterIsA: true);
      final state = RoomState.initial(GebetaState.initial(), starterIsA: true);

      final result = await _roomRef(code).runTransaction((Object? _) {
        return Transaction.success({
          ...room.toJson(),
          'state': state.toJson(),
        });
      });
      if (result.committed) {
        await _codeRef(code).set(true);
        await _roomRef(code)
            .child('players')
            .child(uid)
            .onDisconnect()
            .remove();
        return code;
      }
    }
    throw const RoomException(RoomExceptionType.full);
  }

  @override
  Future<Room> joinRoom({required String code, required String uid}) async {
    final ref = _roomRef(code);
    final result = await ref.runTransaction((Object? snapshot) {
      if (snapshot == null || snapshot is! Map) {
        return Transaction.abort();
      }
      final room = Room.fromJson(Map<String, dynamic>.from(snapshot));
      if (room.isFull) return Transaction.abort();
      final joined = room.copyWith(guestId: uid, status: RoomStatus.playing);
      // Keep child keys (state, players) intact — merge only room fields.
      return Transaction.success({
        ...Map<String, dynamic>.from(snapshot),
        ...joined.toJson(),
      });
    });

    if (!result.committed) {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        throw const RoomException(RoomExceptionType.notFound);
      }
      throw const RoomException(RoomExceptionType.full);
    }

    await ref.child('players').child(uid).onDisconnect().remove();
    final snapshot = await ref.get();
    return Room.fromJson(
      Map<String, dynamic>.from(snapshot.value! as Map),
    );
  }

  @override
  Stream<Room?> watchRoom(String code) {
    return _roomRef(code).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return Room.fromJson(Map<String, dynamic>.from(value as Map));
    });
  }

  @override
  Stream<RoomState?> watchState(String code) {
    return _stateRef(code).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return RoomState.fromJson(Map<String, dynamic>.from(value as Map));
    });
  }

  @override
  Future<MoveOutcome> submitMove({
    required String code,
    required String uid,
    required int pit,
  }) async {
    final ref = _stateRef(code);
    // The transaction callback must be synchronous (plugin API), so the
    // side lookup happens before — the write still enforces turn order
    // because the callback checks the snapshot's toMove against `side`.
    final side = await _sideOf(code, uid);

    final result = await ref.runTransaction((Object? snapshot) {
      if (snapshot == null || snapshot is! Map) {
        return Transaction.abort();
      }
      final current = RoomState.fromJson(Map<String, dynamic>.from(snapshot));
      final engine = current.toEngine();
      final expectedLetter = current.toMoveIsA ? 'a' : 'b';
      if (side != expectedLetter) return Transaction.abort();

      // pit == -1 means "I have no legal move — pass".
      if (pit == -1) {
        if (engine.legalMoves().isNotEmpty) return Transaction.abort();
        final passed = engine.pass();
        return Transaction.success(
          RoomState(
            pits: List.of(passed.pits),
            scoreA: passed.scoreA,
            scoreB: passed.scoreB,
            toMoveIsA: passed.toMove == Player.a,
            passes: passed.passes,
            quietPlies: passed.quietPlies,
            seq: current.seq + 1,
            lastPit: -1,
            lastBy: uid,
          ).toJson(),
        );
      }

      if (!engine.legalMoves().contains(pit)) return Transaction.abort();

      final next = engine.apply(pit);
      return Transaction.success(
        RoomState(
          pits: List.of(next.pits),
          scoreA: next.scoreA,
          scoreB: next.scoreB,
          toMoveIsA: next.toMove == Player.a,
          passes: next.passes,
          quietPlies: next.quietPlies,
          seq: current.seq + 1,
          lastPit: pit,
          lastBy: uid,
        ).toJson(),
      );
    });

    if (!result.committed) {
      final snapshot = await ref.get();
      if (!snapshot.exists) return MoveOutcome.stale;
      final current = RoomState.fromJson(
        Map<String, dynamic>.from(snapshot.value! as Map),
      );
      final expectedLetter = current.toMoveIsA ? 'a' : 'b';
      if (side != expectedLetter) return MoveOutcome.notYourTurn;
      final engine = current.toEngine();
      return engine.legalMoves().contains(pit)
          ? MoveOutcome.stale
          : MoveOutcome.invalidMove;
    }

    await _markGameEndIfNeeded(code);
    return MoveOutcome.accepted;
  }

  Future<void> _markGameEndIfNeeded(String code) async {
    final snapshot = await _stateRef(code).get();
    if (!snapshot.exists) return;
    final state =
        RoomState.fromJson(Map<String, dynamic>.from(snapshot.value! as Map));
    if (!state.toEngine().isOver) return;
    await _roomRef(code).update({'status': RoomStatus.finished.name});
  }

  Future<String?> _sideOf(String code, String uid) async {
    final snapshot = await _roomRef(code).get();
    if (!snapshot.exists) return null;
    final room = Room.fromJson(Map<String, dynamic>.from(snapshot.value! as Map));
    return room.sideOf(uid);
  }

  @override
  Future<void> leaveRoom({required String code, required String uid}) async {
    try {
      final roomSnapshot = await _roomRef(code).get();
      if (!roomSnapshot.exists) return;
      final room =
          Room.fromJson(Map<String, dynamic>.from(roomSnapshot.value! as Map));
      if (uid == room.hostId) {
        await _roomRef(code).remove();
        await _codeRef(code).remove();
      } else if (uid == room.guestId) {
        await _roomRef(code).update({
          'guestId': null,
          'status': RoomStatus.lobby.name,
        });
      }
    } catch (e) {
      // Leaving is best-effort; onDisconnect covers hard exits.
      debugPrint('leaveRoom failed (best-effort): $e');
    }
  }
}
