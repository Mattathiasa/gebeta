import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/game_controller.dart';
import '../domain/game_engine.dart';
import '../domain/local_game_controller.dart';
import 'widgets/gebeta_board.dart';

/// Two players, one device: the board flips each turn (see
/// [LocalGameState.boardState]) and a hand-off screen sits between
/// turns so nobody has to narrate "okay, now tap your own pits."
class PassAndPlayScreen extends ConsumerStatefulWidget {
  const PassAndPlayScreen({super.key});

  @override
  ConsumerState<PassAndPlayScreen> createState() => _PassAndPlayScreenState();
}

class _PassAndPlayScreenState extends ConsumerState<PassAndPlayScreen> {
  bool _started = false;
  bool _awaitingHandoff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      ref.read(localGameStateProvider.notifier).newGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGameStateProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen(localGameStateProvider, (previous, next) {
      if (next.gameOver && !(previous?.gameOver ?? false)) {
        _showResultSheet(next.board.result ?? 0);
        return;
      }
      // A turn just settled (animating → humanTurn) and the mover
      // changed — time to hand the device to the other player.
      if (previous != null &&
          previous.phase != GameStatePhase.humanTurn &&
          next.phase == GameStatePhase.humanTurn &&
          !next.gameOver) {
        setState(() => _awaitingHandoff = true);
      }
    });

    final toMoveIsA = state.board.toMove == Player.a;
    final turnLabel = toMoveIsA ? l10n.playerATurn : l10n.playerBTurn;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passAndPlay),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: GebetaSpacing.md),
            child: Center(
              child: Text(
                '${state.winsA}–${state.winsB}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: GebetaSpacing.page,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: GebetaBoard(
                            state: state.boardState,
                            onPitTap:
                                ref.read(localGameStateProvider.notifier).tapPit,
                          ),
                        ),
                      ),
                      const SizedBox(height: GebetaSpacing.md),
                      Text(
                        state.gameOver ? '' : turnLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (_awaitingHandoff)
                    _HandoffOverlay(
                      toMoveIsA: toMoveIsA,
                      onContinue: () => setState(() => _awaitingHandoff = false),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showResultSheet(int result) {
    final l10n = AppLocalizations.of(context);
    final title = result > 0
        ? l10n.playerAWins
        : result < 0
            ? l10n.playerBWins
            : l10n.draw;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GebetaRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GebetaSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.headlineMedium?.copyWith(
                      color: result == 0 ? null : GebetaColors.win,
                    ),
              ),
              const SizedBox(height: GebetaSpacing.lg),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(localGameStateProvider.notifier).newGame();
                },
                child: Text(l10n.newGame),
              ),
              const SizedBox(height: GebetaSpacing.md),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.pop();
                },
                child: Text(l10n.quitGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandoffOverlay extends StatelessWidget {
  const _HandoffOverlay({required this.toMoveIsA, required this.onContinue});

  final bool toMoveIsA;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Positioned.fill(
      child: Material(
        color: GebetaColors.woodDarkest.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(GebetaRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(GebetaRadius.lg),
          onTap: onContinue,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(GebetaSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, color: GebetaColors.honey, size: 40),
                  const SizedBox(height: GebetaSpacing.md),
                  Text(
                    l10n.passDeviceTitle,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(color: GebetaColors.onDark),
                  ),
                  const SizedBox(height: GebetaSpacing.sm),
                  Text(
                    toMoveIsA ? l10n.passToPlayerA : l10n.passToPlayerB,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: GebetaColors.onDark.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: GebetaSpacing.lg),
                  FilledButton(
                    onPressed: onContinue,
                    child: Text(l10n.tapToContinue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
