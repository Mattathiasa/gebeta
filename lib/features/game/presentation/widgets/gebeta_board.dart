import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/game_controller.dart';
import '../../domain/game_engine.dart';
import 'pit_circle.dart';

/// The playable board: opponent's row on top (mirrored), yours on the
/// bottom, captured-seed tallies on the sides.
///
/// Takes its state and tap callback as inputs so the same board serves
/// AI matches ([gameStateProvider]) and online rooms.
class GebetaBoard extends StatelessWidget {
  const GebetaBoard({
    super.key,
    required this.state,
    required this.onPitTap,
  });

  final GameState state;
  final void Function(int pit) onPitTap;

  @override
  Widget build(BuildContext context) {
    final board = state.board;
    final mySide = state.mySide;
    final legal = state.humanCanTap ? board.legalMoves() : const <int>[];

    // Bottom row is always your side, in sow order left→right; the
    // opponent's row sits on top mirrored so the sow path reads as one
    // continuous loop around the board.
    final bottomIndices = mySide == Player.a
        ? const [0, 1, 2, 3, 4, 5]
        : const [6, 7, 8, 9, 10, 11];
    final topIndices = mySide == Player.a
        ? const [11, 10, 9, 8, 7, 6]
        : const [5, 4, 3, 2, 1, 0];
    final myScore = board.scoreOf(mySide);
    final oppScore = board.scoreOf(opponentOf(mySide));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 6 pits per row + gaps; keep the board readable on both a
        // phone and a desktop browser.
        final pitSize = ((width - GebetaSpacing.md * 2) / 6.8).clamp(36.0, 84.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScoreRow(
              label: AppLocalizations.of(context).opponentTurn,
              score: oppScore,
              isTurn: board.toMove != mySide && !state.gameOver,
              thinking: state.phase == GameStatePhase.aiThinking,
            ),
            SizedBox(height: GebetaSpacing.sm),
            _PitRow(
              indices: topIndices,
              pitSize: pitSize,
              state: state,
              legal: legal,
              onTap: onPitTap,
            ),
            SizedBox(height: GebetaSpacing.sm),
            _PitRow(
              indices: bottomIndices,
              pitSize: pitSize,
              state: state,
              legal: legal,
              onTap: onPitTap,
            ),
            SizedBox(height: GebetaSpacing.sm),
            _ScoreRow(
              label: AppLocalizations.of(context).yourTurn,
              score: myScore,
              isTurn: board.toMove == mySide && !state.gameOver,
              thinking: state.phase == GameStatePhase.humanTurn,
            ),
          ],
        );
      },
    );
  }
}

class _PitRow extends StatelessWidget {
  const _PitRow({
    required this.indices,
    required this.pitSize,
    required this.state,
    required this.legal,
    required this.onTap,
  });

  final List<int> indices;
  final double pitSize;
  final GameState state;
  final List<int> legal;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final i in indices) ...[
          PitCircle(
            seeds: state.board.pits[i],
            size: pitSize,
            isLegal: legal.contains(i),
            isHighlighted: state.highlightedPit == i,
            isCaptured: state.captureFlash.contains(i),
            onTap: () => onTap(i),
          ),
          if (i != indices.last) SizedBox(width: pitSize * 0.12),
        ],
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.isTurn,
    required this.thinking,
  });

  final String label;
  final int score;
  final bool isTurn;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GebetaSpacing.md,
            vertical: GebetaSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isTurn
                ? GebetaColors.gold
                : GebetaColors.wood.withValues(alpha: 0.25),
            borderRadius: GebetaRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: text.titleMedium?.copyWith(
                  color: isTurn ? GebetaColors.woodDarkest : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (thinking) ...[
                const SizedBox(width: GebetaSpacing.sm),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isTurn ? GebetaColors.woodDarkest : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: GebetaSpacing.md),
        Text(label, style: text.bodyMedium),
      ],
    );
  }
}
