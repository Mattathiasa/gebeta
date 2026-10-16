import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../game/presentation/widgets/gebeta_board.dart';
import '../domain/online_game_controller.dart';

class OnlineGameScreen extends ConsumerWidget {
  const OnlineGameScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onlineGameStateProvider(code));
    final controller = ref.read(onlineGameStateProvider(code).notifier);

    ref.listen(onlineGameStateProvider(code), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
      if (next.validationFailed && !(previous?.validationFailed ?? false)) {
        _showDesyncSheet(context);
      }
      if (next.board.isOver && !(previous?.board.isOver ?? false)) {
        _showResultSheet(context, next.result ?? 0);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(code),
        leading: IconButton(
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.copied)),
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await controller.leave();
              if (context.mounted) context.go(Routes.home);
            },
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
                        state: state.boardState,
                        onPitTap: controller.submitPit,
                      ),
                    ),
                  ),
                  const SizedBox(height: GebetaSpacing.md),
                  Text(
                    state.gameOver
                        ? ''
                        : state.myTurn
                            ? l10n.yourTurn
                            : l10n.opponentTurn,
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

  void _showDesyncSheet(BuildContext context) {
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
                'Move rejected',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.headlineMedium?.copyWith(
                      color: GebetaColors.danger,
                    ),
              ),
              const SizedBox(height: GebetaSpacing.md),
              Text(
                'The opponent\'s move did not match the rules of the game. '
                'The match has been left to protect fair play.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: GebetaSpacing.lg),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.go(Routes.home);
                },
                child: const Text('Back home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultSheet(BuildContext context, int result) {
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
                  context.go(Routes.home);
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
