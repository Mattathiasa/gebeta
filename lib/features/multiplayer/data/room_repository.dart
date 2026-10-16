import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_bootstrap.dart';
import '../domain/room.dart';
import 'rtdb_room_repository.dart';
import 'stub_room_repository.dart';

/// Outcome of a move submission — mirrors what the engine guarantees.
enum MoveOutcome { accepted, notYourTurn, invalidMove, stale }

/// Backend for room-code online play.
///
/// Two implementations swap behind this interface (karaoki pattern):
/// RTDB when Firebase is configured, an in-memory stub otherwise so the
/// lobby is demoable in dev and unit-testable anywhere.
abstract class RoomRepository {
  Future<String> createRoom({required String uid});
  Future<Room> joinRoom({required String code, required String uid});
  Stream<Room?> watchRoom(String code);
  Stream<RoomState?> watchState(String code);
  Future<MoveOutcome> submitMove({
    required String code,
    required String uid,
    required int pit,
  });
  Future<void> leaveRoom({required String code, required String uid});
  void dispose() {}
}

enum RoomExceptionType { notFound, full }

class RoomException implements Exception {
  const RoomException(this.type);
  final RoomExceptionType type;

  @override
  String toString() => type == RoomExceptionType.notFound
      ? 'Room not found'
      : 'Room is full';
}

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final repo = firebaseIsConfigured
      ? RtdbRoomRepository()
      : StubRoomRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// 4-character room codes: unambiguous alphabet (no 0/O/1/I), easy to
/// read aloud across a phone call.
String generateRoomCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final seed = DateTime.now().microsecondsSinceEpoch;
  var x = seed;
  final buffer = StringBuffer();
  for (var i = 0; i < 4; i++) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    buffer.write(alphabet[x % alphabet.length]);
  }
  return buffer.toString();
}
