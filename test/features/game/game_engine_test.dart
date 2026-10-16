import 'package:flutter_test/flutter_test.dart';
import 'package:gebeta/core/utils/seeded_rng.dart';
import 'package:gebeta/features/game/domain/game_engine.dart';

GebetaState state({
  required List<int> pits,
  Player toMove = Player.a,
  int scoreA = 0,
  int scoreB = 0,
  int passes = 0,
  int quietPlies = 0,
}) =>
    GebetaState(
      pits: pits,
      scoreA: scoreA,
      scoreB: scoreB,
      toMove: toMove,
      passes: passes,
      quietPlies: quietPlies,
    );

void main() {
  group('initial position', () {
    test('12 pits of 4, no scores, Player.a to move', () {
      final s = GebetaState.initial();
      expect(s.pits, List.filled(12, 4));
      expect(s.scoreA, 0);
      expect(s.scoreB, 0);
      expect(s.toMove, Player.a);
      expect(s.legalMoves(), [0, 1, 2, 3, 4, 5]);
    });

    test('starter parameter flips the turn', () {
      final s = GebetaState.initial(starter: Player.b);
      expect(s.toMove, Player.b);
      expect(s.legalMoves(), [6, 7, 8, 9, 10, 11]);
    });
  });

  group('sowing', () {
    test('sow from pit 0 distributes 4 seeds forward', () {
      final s = state(pits: [
        4, 4, 4, 4, 4, 4, // a
        4, 4, 4, 4, 4, 4, // b
      ]).apply(0);
      expect(s.pits, [0, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4]);
      expect(s.toMove, Player.b);
    });

    test('sow wraps past pit 11 back to pit 0', () {
      final s = state(pits: [
        0, 0, 0, 0, 0, 3, // a — pit 5 has 3
        0, 0, 0, 0, 0, 0, // b
      ]).apply(5);
      // lands 6, 7, 8
      expect(s.pits, [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]);
    });

    test('sow from b wraps 11 → 0', () {
      final s = state(
        pits: [
          0, 0, 0, 0, 0, 0, // a
          0, 0, 0, 0, 0, 1, // b — pit 11 has 1
        ],
        toMove: Player.b,
      ).apply(11);
      expect(s.pits, [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(s.toMove, Player.a);
    });
  });

  group('capture — rule 1 (opponent row, 2 or 3, chain backward)', () {
    test('single capture of a pair', () {
      final s = state(pits: [
        0, 0, 0, 0, 0, 1, // a — pit 5 has 1, lands in pit 6
        1, 0, 0, 0, 0, 0, // b — pit 6 becomes 2 → captured
      ]).apply(5);
      expect(s.scoreA, 2);
      expect(s.pits[6], 0);
    });

    test('backward chain captures 2-2-2', () {
      // sow from 5 (3 seeds) → 6,7,8 each become 2 → all captured
      final s = state(pits: [
        0, 0, 0, 0, 0, 3,
        1, 1, 1, 0, 0, 0,
      ]).apply(5);
      expect(s.scoreA, 6);
      expect(s.pits.sublist(6), [0, 0, 0, 0, 0, 0]);
    });

    test('chain stops at a pit that is not 2 or 3', () {
      // sow from 5 (3 seeds) → pits 6,7,8 get one each: 6→1, 7→4, 8→2.
      // Last seed lands on pit 8 (2) → captured; backward to 7 which is
      // 4 → chain stops. Pit 6 (1) never reached.
      final s = state(pits: [
        0, 0, 0, 0, 0, 3,
        0, 3, 1, 0, 0, 0,
      ]).apply(5);
      expect(s.scoreA, 2);
      expect(s.pits[8], 0);
      expect(s.pits[7], 4);
      expect(s.pits[6], 1);
    });

    test('4 is never captured', () {
      final s = state(pits: [
        0, 0, 0, 0, 0, 1,
        3, 0, 0, 0, 0, 0, // pit 6: 3+1 = 4 → no capture
      ]).apply(5);
      expect(s.scoreA, 0);
      expect(s.pits[6], 4);
    });
  });

  group('capture — rule 2 (own-row "no capture" fallback)', () {
    test('lands on own pair → captured', () {
      // b keeps a far-away seed so the "give seeds" rule stays quiet.
      final s = state(pits: [
        0, 0, 0, 0, 1, 1, // sow pit 4 → lands pit 5 (1+1=2)
        0, 0, 0, 0, 0, 5,
      ]).apply(4);
      expect(s.scoreA, 2);
      expect(s.pits[5], 0);
    });

    test('rule 2 suppressed when rule 1 fired', () {
      // Sow from 4 (2 seeds) → pit 5 (own, 2→3), pit 6 (opp, 1→2).
      // Rule 1 captures pit 6; the chain then steps back onto own pit 5,
      // which holds 3 — rule 2 must NOT take it because rule 1 fired.
      final s = state(pits: [
        0, 0, 0, 0, 2, 2,
        1, 0, 0, 0, 0, 4,
      ]).apply(4);
      expect(s.scoreA, 2); // only the opponent's pair
      expect(s.pits[5], 3); // own triple survives
      expect(s.pits[6], 0);
    });
  });

  group('starvation rules', () {
    test('a move that captures the opponent\'s last seeds is illegal', () {
      // a's pit 5 (1 seed) would land on b's only seed, making a pair
      // that is captured — leaving b empty. a's pit 0 is a safe
      // alternative (lands on own pit 1), so move 5 must be rejected.
      final s = state(pits: [
        1, 0, 0, 0, 0, 1,
        1, 0, 0, 0, 0, 0,
      ]);
      expect(s.legalMoves(), [0]);
      expect(() => s.apply(5), throwsArgumentError);
    });

    test('but the starving move is forced when it is the only option', () {
      final s = state(pits: [
        0, 0, 0, 0, 0, 1,
        1, 0, 0, 0, 0, 0,
      ]);
      // pit 5 is a's only non-empty pit, so it must be allowed anyway.
      expect(s.legalMoves(), [5]);
    });

    test('with an empty opponent row you must give seeds', () {
      // b is empty; a's pit 0 (1 seed) lands in pit 1 (own row) — gives
      // nothing. Pit 5 (1 seed) lands in pit 6 — gives b a seed.
      final s = state(pits: [
        1, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0,
      ]);
      expect(s.legalMoves(), [5]);
      // and the move is legal:
      expect(() => s.apply(0), throwsArgumentError);
    });
  });

  group('passing and game end', () {
    test('pass() flips turn and counts', () {
      final s = state(
        pits: [
          0, 0, 0, 0, 0, 0, // a empty → must pass
          1, 0, 0, 0, 0, 0,
        ],
        toMove: Player.a,
      );
      expect(s.legalMoves(), isEmpty);
      final p = s.pass();
      expect(p.toMove, Player.b);
      expect(p.passes, 1);
    });

    test('pass() throws while moves remain', () {
      expect(() => GebetaState.initial().pass(), throwsStateError);
    });

    test('two consecutive passes end the game', () {
      // Both rows empty except seeds that cannot reach the other side:
      // construct both-empty board — every pass flips and re-checks.
      final s = state(
        pits: List.filled(12, 0),
        toMove: Player.a,
      );
      final afterOne = s.pass();
      expect(afterOne.isOver, isFalse);
      final afterTwo = afterOne.pass();
      expect(afterTwo.isOver, isTrue);
      expect(afterTwo.result, 0); // 0–0 draw
    });

    test('result: majority of 48 decides', () {
      final aWins = state(
        pits: List.filled(12, 0),
        scoreA: 25,
        scoreB: 23,
        passes: 2,
      );
      expect(aWins.result, 1);
      final bWins = state(
        pits: List.filled(12, 0),
        scoreA: 24,
        scoreB: 24,
        passes: 2,
      );
      expect(bWins.result, 0); // 24–24 is a draw, not a win
    });

    test('stalemate: 50 quiet plies without a capture ends the game', () {
      final s = state(
        pits: List.filled(12, 1),
        scoreA: 30,
        scoreB: 10,
        quietPlies: GebetaState.maxQuietPlies,
      );
      expect(s.isOver, isTrue);
      expect(s.result, 1);
    });
  });

  group('invariants under random play', () {
    test('seeds are conserved across 200 random games', () {
      for (var game = 0; game < 200; game++) {
        var s = GebetaState.initial(
          starter: game.isEven ? Player.a : Player.b,
        );
        var plies = 0;
        while (!s.isOver && plies < 500) {
          final moves = s.legalMoves();
          if (moves.isEmpty) {
            s = s.pass();
            continue;
          }
          final rng = SeededRng(game * 1000 + plies);
          s = s.apply(moves[rng.nextInt(moves.length)]);
          final onBoard = s.pits.fold<int>(0, (sum, p) => sum + p);
          expect(
            onBoard + s.scoreA + s.scoreB,
            GebetaState.totalSeeds,
            reason: 'game $game ply $plies lost or created seeds',
          );
          plies++;
        }
        expect(s.isOver, isTrue, reason: 'game $game never ended');
      }
    });

    test('captures never exceed what is on the board', () {
      var s = GebetaState.initial();
      final rng = SeededRng(42);
      var plies = 0;
      while (!s.isOver && plies < 400) {
        final moves = s.legalMoves();
        if (moves.isEmpty) {
          s = s.pass();
          continue;
        }
        s = s.apply(moves[rng.nextInt(moves.length)]);
        expect(s.scoreA + s.scoreB, lessThanOrEqualTo(GebetaState.totalSeeds));
        plies++;
      }
    });
  });

  group('equality', () {
    test('same position == same position', () {
      final a1 = state(pits: List.filled(12, 4));
      final a2 = state(pits: List.filled(12, 4));
      expect(a1, a2);
      expect(a1.hashCode, a2.hashCode);
    });
  });
}
