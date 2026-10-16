import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../data/room_repository.dart';
import '../domain/room.dart';

enum LobbyPhase { idle, creating, joining, waiting, inRoom, error }

class LobbyState {
  const LobbyState({
    this.phase = LobbyPhase.idle,
    this.code,
    this.isHost = false,
    this.error,
  });

  final LobbyPhase phase;
  final String? code;
  final bool isHost;
  final String? error;

  LobbyState copyWith({
    LobbyPhase? phase,
    String? code,
    bool? isHost,
    String? error,
    bool clearError = false,
    bool clearCode = false,
  }) =>
      LobbyState(
        phase: phase ?? this.phase,
        code: clearCode ? null : (code ?? this.code),
        isHost: isHost ?? this.isHost,
        error: clearError ? null : (error ?? this.error),
      );
}

final lobbyControllerProvider =
    NotifierProvider<LobbyController, LobbyState>(LobbyController.new);

class LobbyController extends Notifier<LobbyState> {
  StreamSubscription<Room?>? _roomSub;

  @override
  LobbyState build() {
    ref.onDispose(() => _roomSub?.cancel());
    return const LobbyState();
  }

  Future<void> createRoom() async {
    state = state.copyWith(phase: LobbyPhase.creating, clearError: true);
    try {
      final repo = ref.read(roomRepositoryProvider);
      final uid = await ref.read(uidProvider.future);
      final code = await repo.createRoom(uid: uid);
      state = state.copyWith(
        phase: LobbyPhase.waiting,
        code: code,
        isHost: true,
      );
      _watchRoom(code, uid);
    } catch (e) {
      state = state.copyWith(phase: LobbyPhase.error, error: '$e');
    }
  }

  Future<void> joinRoom(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length != 4) {
      state = state.copyWith(
        phase: LobbyPhase.error,
        error: 'Enter the 4-letter room code',
      );
      return;
    }
    state = state.copyWith(phase: LobbyPhase.joining, clearError: true);
    try {
      final repo = ref.read(roomRepositoryProvider);
      final uid = await ref.read(uidProvider.future);
      await repo.joinRoom(code: code, uid: uid);
      state = state.copyWith(
        phase: LobbyPhase.inRoom,
        code: code,
        isHost: false,
      );
      _watchRoom(code, uid);
    } on RoomException catch (e) {
      state = state.copyWith(phase: LobbyPhase.error, error: e.toString());
    } catch (e) {
      state = state.copyWith(phase: LobbyPhase.error, error: '$e');
    }
  }

  void _watchRoom(String code, String uid) {
    _roomSub?.cancel();
    _roomSub = ref.read(roomRepositoryProvider).watchRoom(code).listen((room) {
      if (room == null) {
        // Host deleted the room out from under us.
        state = state.copyWith(
          phase: LobbyPhase.error,
          error: 'Room closed',
          clearCode: true,
        );
        return;
      }
      if (room.status == RoomStatus.playing && room.sideOf(uid) != null) {
        state = state.copyWith(phase: LobbyPhase.inRoom, code: code);
      }
    });
  }

  Future<void> exitLobby() async {
    final code = state.code;
    final uid = await ref.read(uidProvider.future);
    if (code != null) {
      await ref.read(roomRepositoryProvider).leaveRoom(code: code, uid: uid);
    }
    _roomSub?.cancel();
    state = const LobbyState();
  }

  void reset() {
    _roomSub?.cancel();
    state = const LobbyState();
  }
}
