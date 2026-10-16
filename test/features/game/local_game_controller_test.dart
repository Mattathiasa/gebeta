import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebeta/features/game/domain/game_engine.dart';
import 'package:gebeta/features/game/domain/local_game_controller.dart';

void main() {
  setUp(() {
    LocalGameController.debugDelayScale = 0;
  });

  tearDown(() {
    LocalGameController.debugDelayScale = 1.0;
  });

  test('newGame deals a fresh, seed-conserving board', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(localGameStateProvider.notifier);

    controller.newGame();
    final state = container.read(localGameStateProvider);
    expect(state.gameOver, isFalse);
    final onBoard = state.board.pits.fold<int>(0, (s, p) => s + p);
    expect(onBoard + state.board.scoreA + state.board.scoreB,
        GebetaState.totalSeeds);
  });

  test('boardState always seats the mover at the bottom', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(localGameStateProvider.notifier);
    controller.newGame();

    final before = container.read(localGameStateProvider);
    expect(before.boardState.mySide, before.board.toMove);
    expect(before.boardState.humanCanTap, isTrue);

    final legal = before.board.legalMoves();
    await controller.tapPit(legal.first);
    final after = container.read(localGameStateProvider);
    // Either the mover flipped to the other player, or the same player
    // got another turn (e.g. a capture that doesn't pass turn — this
    // engine always passes the turn, so expect a flip unless the game
    // ended).
    expect(after.boardState.mySide, after.board.toMove);
    if (!after.gameOver) {
      expect(after.boardState.humanCanTap, isTrue);
    }
  });

  test('illegal taps are ignored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(localGameStateProvider.notifier);
    controller.newGame();

    final before = container.read(localGameStateProvider).board;
    final illegal = before.toMove == Player.a ? 9 : 0;
    await controller.tapPit(illegal);
    expect(container.read(localGameStateProvider).board, before);
  });

  test('a full match completes and tallies a winner or a draw', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(localGameStateProvider.notifier);
    controller.newGame();

    var guard = 0;
    while (!container.read(localGameStateProvider).gameOver && guard < 400) {
      final state = container.read(localGameStateProvider);
      final moves = state.board.legalMoves();
      if (moves.isNotEmpty) {
        await controller.tapPit(moves.first);
      }
      guard++;
    }
    final finalState = container.read(localGameStateProvider);
    expect(finalState.gameOver, isTrue);
    expect(finalState.winsA + finalState.winsB + finalState.draws, 1);
  });
}
