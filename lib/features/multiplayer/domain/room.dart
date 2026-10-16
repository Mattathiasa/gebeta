import '../../game/domain/game_engine.dart';

enum RoomStatus { lobby, playing, finished }

/// Lobby record at `rooms/{code}`.
class Room {
  const Room({
    required this.code,
    required this.hostId,
    this.guestId,
    this.status = RoomStatus.lobby,
    required this.starterIsA,
  });

  final String code;
  final String hostId; // always Player.a
  final String? guestId; // Player.b once joined
  final RoomStatus status;
  final bool starterIsA;

  bool get isFull => guestId != null;

  String? sideOf(String uid) {
    if (uid == hostId) return 'a';
    if (uid == guestId) return 'b';
    return null;
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'hostId': hostId,
        'guestId': guestId,
        'status': status.name,
        'starterIsA': starterIsA,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        code: json['code'] as String,
        hostId: json['hostId'] as String,
        guestId: json['guestId'] as String?,
        status: RoomStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => RoomStatus.lobby,
        ),
        starterIsA: json['starterIsA'] as bool? ?? true,
      );

  Room copyWith({String? guestId, RoomStatus? status}) => Room(
        code: code,
        hostId: hostId,
        guestId: guestId ?? this.guestId,
        status: status ?? this.status,
        starterIsA: starterIsA,
      );
}

/// Engine snapshot at `rooms/{code}/state`, versioned by [seq].
/// Every accepted move bumps seq by exactly 1 and names its pit, so
/// receivers can re-validate against their local copy (dual-compute —
/// we have no server runtime, see docs/ARCHITECTURE.md).
class RoomState {
  const RoomState({
    required this.pits,
    required this.scoreA,
    required this.scoreB,
    required this.toMoveIsA,
    required this.passes,
    required this.quietPlies,
    required this.seq,
    this.lastPit,
    this.lastBy,
  });

  final List<int> pits;
  final int scoreA;
  final int scoreB;
  final bool toMoveIsA;
  final int passes;
  final int quietPlies;
  final int seq;

  /// The pit that produced this snapshot (null at game start).
  final int? lastPit;

  /// uid of the player who wrote this snapshot.
  final String? lastBy;

  GebetaState toEngine() => GebetaState(
        pits: List.of(pits),
        scoreA: scoreA,
        scoreB: scoreB,
        toMove: toMoveIsA ? Player.a : Player.b,
        passes: passes,
        quietPlies: quietPlies,
      );

  static RoomState initial(GebetaState board, {required bool starterIsA}) =>
      RoomState(
        pits: List.of(board.pits),
        scoreA: board.scoreA,
        scoreB: board.scoreB,
        toMoveIsA: starterIsA,
        passes: board.passes,
        quietPlies: board.quietPlies,
        seq: 0,
      );

  Map<String, dynamic> toJson() => {
        'pits': pits,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'toMoveIsA': toMoveIsA,
        'passes': passes,
        'quietPlies': quietPlies,
        'seq': seq,
        if (lastPit != null) 'lastPit': lastPit,
        if (lastBy != null) 'lastBy': lastBy,
      };

  factory RoomState.fromJson(Map<String, dynamic> json) => RoomState(
        pits: List<int>.from(json['pits'] as List),
        scoreA: (json['scoreA'] as num).toInt(),
        scoreB: (json['scoreB'] as num).toInt(),
        toMoveIsA: json['toMoveIsA'] as bool,
        passes: (json['passes'] as num?)?.toInt() ?? 0,
        quietPlies: (json['quietPlies'] as num?)?.toInt() ?? 0,
        seq: (json['seq'] as num).toInt(),
        lastPit: (json['lastPit'] as num?)?.toInt(),
        lastBy: json['lastBy'] as String?,
      );
}
