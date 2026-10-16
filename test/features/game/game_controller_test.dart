import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebeta/features/game/domain/ai_engine.dart';
import 'package:gebeta/features/game/domain/game_controller.dart';
import 'package:gebeta/features/game/domain/game_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameController.debugDelayScale = 0;
  });

  tearDown(() {
    GameController.debugDelayScale = 1.0;
  });

  test('newGame deals a fresh board and the AI answers the human', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gameStateProvider.notifier);

    await controller.newGame(difficulty: AiDifficulty.easy);
    final afterStart = container.read(gameStateProvider);
    // The starter is randomized: either the human stares at the fresh
    // board, or the AI already opened and handed the turn back.
    expect(afterStart.gameOver, isFalse);
    expect(afterStart.board.toMove, Player.a);
    final onBoard = afterStart.board.pits.fold<int>(0, (s, p) => s + p);
    expect(
      onBoard + afterStart.board.scoreA + afterStart.board.scoreB,
      GebetaState.totalSeeds,
    );

    final legal = afterStart.board.legalMoves();
    await controller.tapPit(legal.first);
    final afterHuman = container.read(gameStateProvider);
    // Human moved → AI moved → human again (or the game ended).
    expect(
      afterHuman.board.toMove == Player.a || afterHuman.gameOver,
      isTrue,
    );
  });

  test('illegal taps are ignored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gameStateProvider.notifier);
    await controller.newGame(difficulty: AiDifficulty.easy);

    final before = container.read(gameStateProvider).board;
    // Opponent's pits are never tappable by the human.
    await controller.tapPit(9);
    expect(container.read(gameStateProvider).board, before);
  });

  test('a full easy match completes and records stats', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gameStateProvider.notifier);
    await controller.newGame(difficulty: AiDifficulty.easy);

    var guard = 0;
    while (!container.read(gameStateProvider).gameOver && guard < 400) {
      final state = container.read(gameStateProvider);
      final moves = state.board.legalMoves();
      // Human's turn: play the first legal move (controller auto-passes
      // stuck turns internally).
      if (state.phase == GameStatePhase.humanTurn && moves.isNotEmpty) {
        await controller.tapPit(moves.first);
      } else if (state.phase == GameStatePhase.humanTurn && moves.isEmpty) {
        break; // shouldn't happen — controller auto-passes
      }
      guard++;
    }
    final finalState = container.read(gameStateProvider);
    expect(finalState.gameOver, isTrue);
    expect(finalState.stats.gamesPlayed, greaterThanOrEqualTo(1));
  });
}
