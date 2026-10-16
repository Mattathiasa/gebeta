import 'package:flutter_test/flutter_test.dart';
import 'package:gebeta/core/utils/seeded_rng.dart';
import 'package:gebeta/features/game/domain/ai_engine.dart';
import 'package:gebeta/features/game/domain/game_engine.dart';

void main() {
  group('GebetaAi', () {
    test('always returns a legal move on the opening position', () {
      final s = GebetaState.initial();
      for (final d in AiDifficulty.values) {
        final ai = GebetaAi(difficulty: d, rng: SeededRng(7));
        final move = ai.chooseMove(s);
        expect(move, isNotNull);
        expect(s.legalMoves(), contains(move));
      }
    });

    test('returns null when the player must pass', () {
      final s = GebetaState(
        pits: [
          0, 0, 0, 0, 0, 0, // a empty → must pass
          4, 4, 4, 4, 4, 4,
        ],
        scoreA: 10,
        scoreB: 10,
        toMove: Player.a,
      );
      final ai = GebetaAi(difficulty: AiDifficulty.hard, rng: SeededRng(1));
      expect(ai.chooseMove(s), isNull);
    });

    test('hard difficulty takes an obvious capture', () {
      // a can sow from 5 → pit 6 becomes 2 → capture 2 for free.
      final s = GebetaState(
        pits: [
          0, 0, 0, 0, 0, 1,
          1, 5, 5, 5, 5, 5,
        ],
        scoreA: 10,
        scoreB: 10,
        toMove: Player.a,
      );
      final ai = GebetaAi(difficulty: AiDifficulty.hard, rng: SeededRng(3));
      expect(ai.chooseMove(s), 5);
    });

    test('hard search completes opening ply in reasonable time', () {
      final s = GebetaState.initial();
      final ai = GebetaAi(difficulty: AiDifficulty.hard, rng: SeededRng(9));
      final clock = Stopwatch()..start();
      ai.chooseMove(s);
      clock.stop();
      // Budget is 900ms; leave headroom for CI noise.
      expect(clock.elapsedMilliseconds, lessThan(3000));
    });

    test('hard beats easy in a 12-game series', () {
      var hardWins = 0;
      for (var game = 0; game < 12; game++) {
        // Hard plays Player.a, easy plays Player.b, alternating who
        // starts to cancel first-move advantage.
        final starter = game.isEven ? Player.a : Player.b;
        var s = GebetaState.initial(starter: starter);
        final hard = GebetaAi(difficulty: AiDifficulty.hard, rng: SeededRng(game));
        final easy = GebetaAi(difficulty: AiDifficulty.easy, rng: SeededRng(game + 500));

        var plies = 0;
        while (!s.isOver && plies < 600) {
          if (s.legalMoves().isEmpty) {
            s = s.pass();
            continue;
          }
          final ai = s.toMove == Player.a ? hard : easy;
          final move = ai.chooseMove(s)!;
          s = s.apply(move);
          plies++;
        }
        if (s.scoreA > s.scoreB) hardWins++;
      }
      // The minimax bot should crush the 70%-random bot most games.
      expect(hardWins, greaterThanOrEqualTo(9), reason: 'hard vs easy series');
    });

    test('every difficulty finishes a full self-play game', () {
      for (final d in AiDifficulty.values) {
        var s = GebetaState.initial();
        final rng = SeededRng(11);
        var plies = 0;
        while (!s.isOver && plies < 600) {
          if (s.legalMoves().isEmpty) {
            s = s.pass();
            continue;
          }
          // Same difficulty on both sides, but fresh move jitter for easy.
          final ai = GebetaAi(difficulty: d, rng: rng);
          s = s.apply(ai.chooseMove(s)!);
          plies++;
        }
        expect(s.isOver, isTrue, reason: '$d self-play never ended');
      }
    });
  });
}
