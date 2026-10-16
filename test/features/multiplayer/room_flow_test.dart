import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebeta/core/services/auth_service.dart';
import 'package:gebeta/features/multiplayer/data/room_repository.dart';
import 'package:gebeta/features/multiplayer/data/stub_room_repository.dart';
import 'package:gebeta/features/multiplayer/domain/lobby_controller.dart';
import 'package:gebeta/features/multiplayer/domain/room.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StubRoomRepository repo;
  late ProviderContainer host;
  late ProviderContainer guest;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = StubRoomRepository();
    host = ProviderContainer(
      overrides: [roomRepositoryProvider.overrideWithValue(repo)],
    );
    guest = ProviderContainer(
      overrides: [roomRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() {
    host.dispose();
    guest.dispose();
    repo.dispose();
  });

  test('create → join → both sides see a playing room', () async {
    final code = await host
        .read(lobbyControllerProvider.notifier)
        .createRoom()
        .then((_) => host.read(lobbyControllerProvider).code!);
    expect(code, hasLength(4));

    // Guest joins via their own container (different identity).
    await guest.read(lobbyControllerProvider.notifier).joinRoom(code);

    final hostRoom = await repo.watchRoom(code).first;
    expect(hostRoom?.status, RoomStatus.playing);
    expect(hostRoom?.guestId, isNotNull);
    expect(guest.read(lobbyControllerProvider).phase, LobbyPhase.inRoom);
  });

  test('join with a bad code fails cleanly', () async {
    await expectLater(
      guest.read(lobbyControllerProvider.notifier).joinRoom('ZZZZ'),
      completes,
    );
    expect(
      guest.read(lobbyControllerProvider).phase,
      LobbyPhase.error,
    );
  });

  test('join a full room fails', () async {
    final code = await host
        .read(lobbyControllerProvider.notifier)
        .createRoom()
        .then((_) => host.read(lobbyControllerProvider).code!);
    await guest.read(lobbyControllerProvider.notifier).joinRoom(code);

    final third = ProviderContainer(
      overrides: [roomRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(third.dispose);
    await third.read(lobbyControllerProvider.notifier).joinRoom(code);
    expect(
      third.read(lobbyControllerProvider).error,
      'Room is full',
    );
  });

  test('turn enforcement: acting out of turn is rejected', () async {
    final uidHost = await host.read(uidProvider.future);
    final uidGuest = await guest.read(uidProvider.future);
    final code = await repo.createRoom(uid: uidHost);
    await repo.joinRoom(code: code, uid: uidGuest);

    final state = await repo.watchState(code).first;
    // Guest is Player.b; starterIsA is true → guest cannot open.
    expect(state!.toMoveIsA, isTrue);
    final outcome = await repo.submitMove(
      code: code,
      uid: uidGuest,
      pit: 7,
    );
    expect(outcome, MoveOutcome.notYourTurn);
  });

  test('pits outside your own row are rejected', () async {
    final uidHost = await host.read(uidProvider.future);
    final code = await repo.createRoom(uid: uidHost);
    // It is the host's turn (Player.a); pit 7 belongs to Player.b.
    final outcome = await repo.submitMove(code: code, uid: uidHost, pit: 7);
    expect(outcome, MoveOutcome.invalidMove);
  });

  test('a pass (pit -1) is only accepted when no move exists', () async {
    final uidHost = await host.read(uidProvider.future);
    final code = await repo.createRoom(uid: uidHost);
    // Host can move, so a fake pass must be rejected…
    final early = await repo.submitMove(code: code, uid: uidHost, pit: -1);
    expect(early, MoveOutcome.invalidMove);
  });

  test('a full match over the stub backend ends with a result', () async {
    final uidHost = await host.read(uidProvider.future);
    final uidGuest = await guest.read(uidProvider.future);
    final code = await repo.createRoom(uid: uidHost);
    await repo.joinRoom(code: code, uid: uidGuest);

    var moves = 0;
    while (moves < 400) {
      final state = await repo.watchState(code).first;
      if (state!.toEngine().isOver) break;
      final engine = state.toEngine();
      final legal = engine.legalMoves();
      final actor = state.toMoveIsA ? uidHost : uidGuest;
      final outcome = await repo.submitMove(
        code: code,
        uid: actor,
        pit: legal.isEmpty ? -1 : legal.first,
      );
      expect(outcome, MoveOutcome.accepted);
      moves++;
    }
    final finalState = await repo.watchState(code).first;
    expect(finalState!.toEngine().isOver, isTrue);
  });
}
