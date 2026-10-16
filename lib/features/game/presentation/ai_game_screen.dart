import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/ads_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../domain/ai_engine.dart';
import '../domain/game_controller.dart';
import 'widgets/gebeta_board.dart';

class AiGameScreen extends ConsumerStatefulWidget {
  const AiGameScreen({super.key});

  @override
  ConsumerState<AiGameScreen> createState() => _AiGameScreenState();
}

class _AiGameScreenState extends ConsumerState<AiGameScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Defer to after first frame so the provider rebuild doesn't
    // notify during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      ref.read(gameStateProvider.notifier).newGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameStateProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen(gameStateProvider, (previous, next) {
      if (next.gameOver && !(previous?.gameOver ?? false)) {
        // Interstitial between games (never mid-turn). Noop on web.
        ref.read(adServiceProvider).maybeShowInterstitial();
        _showResultSheet(next.result ?? 0);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_difficultyLabel(l10n, state.difficulty)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: GebetaSpacing.md),
            child: Center(
              child: Text(
                '${state.matchWins}–${state.matchLosses}',
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
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: GebetaBoard(
                        state: state,
                        onPitTap: ref.read(gameStateProvider.notifier).tapPit,
                      ),
                    ),
                  ),
                  const SizedBox(height: GebetaSpacing.lg),
                  _DifficultyPicker(current: state.difficulty),
                  const SizedBox(height: GebetaSpacing.md),
                  Text(
                    state.gameOver
                        ? ''
                        : state.phase == GameStatePhase.aiThinking
                            ? l10n.opponentTurn
                            : l10n.yourTurn,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _difficultyLabel(AppLocalizations l10n, AiDifficulty d) {
    switch (d) {
      case AiDifficulty.easy:
        return l10n.difficultyEasy;
      case AiDifficulty.medium:
        return l10n.difficultyMedium;
      case AiDifficulty.hard:
        return l10n.difficultyHard;
    }
  }

  void _showResultSheet(int result) {
    final l10n = AppLocalizations.of(context);
    final title = result > 0
        ? l10n.youWin
        : result < 0
            ? l10n.youLose
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
                      color: result > 0
                          ? GebetaColors.win
                          : result < 0
                              ? GebetaColors.danger
                              : null,
                    ),
              ),
              const SizedBox(height: GebetaSpacing.lg),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(gameStateProvider.notifier).newGame();
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

class _DifficultyPicker extends ConsumerWidget {
  const _DifficultyPicker({required this.current});

  final AiDifficulty current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SegmentedButton<AiDifficulty>(
      segments: [
        ButtonSegment(
          value: AiDifficulty.easy,
          label: Text(l10n.difficultyEasy),
        ),
        ButtonSegment(
          value: AiDifficulty.medium,
          label: Text(l10n.difficultyMedium),
        ),
        ButtonSegment(
          value: AiDifficulty.hard,
          label: Text(l10n.difficultyHard),
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) {
        ref.read(gameStateProvider.notifier).setDifficulty(selection.first);
      },
    );
  }
}
