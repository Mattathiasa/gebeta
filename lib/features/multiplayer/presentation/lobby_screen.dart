import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/lobby_controller.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lobby = ref.watch(lobbyControllerProvider);

    ref.listen(lobbyControllerProvider, (previous, next) {
      if (next.phase == LobbyPhase.inRoom && next.code != null) {
        context.go('${Routes.gameOnline}?code=${next.code}');
      }
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.playOnline),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await ref.read(lobbyControllerProvider.notifier).exitLobby();
            if (context.mounted) context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: GebetaSpacing.page,
              child: switch (lobby.phase) {
                LobbyPhase.idle ||
                LobbyPhase.error =>
                  _IdleActions(
                    codeController: _codeController,
                    onCreate: () =>
                        ref.read(lobbyControllerProvider.notifier).createRoom(),
                    onJoin: () => ref
                        .read(lobbyControllerProvider.notifier)
                        .joinRoom(_codeController.text),
                  ),
                LobbyPhase.creating ||
                LobbyPhase.joining =>
                  const Center(child: CircularProgressIndicator()),
                LobbyPhase.waiting =>
                  _WaitingForGuest(code: lobby.code ?? ''),
                LobbyPhase.inRoom =>
                  const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleActions extends StatelessWidget {
  const _IdleActions({
    required this.codeController,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController codeController;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.createRoom,
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: GebetaSpacing.sm),
        Text(
          'Creates a private table and gives you a code to share.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: GebetaSpacing.md),
        FilledButton(onPressed: onCreate, child: Text(l10n.createRoom)),
        const SizedBox(height: GebetaSpacing.xl),
        Text(
          l10n.joinRoom,
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: GebetaSpacing.md),
        TextField(
          controller: codeController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 4,
          style: text.headlineMedium?.copyWith(letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'ABCD',
            hintStyle: TextStyle(
              letterSpacing: 8,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: GebetaSpacing.md),
        OutlinedButton(onPressed: onJoin, child: Text(l10n.joinRoom)),
      ],
    );
  }
}

class _WaitingForGuest extends StatelessWidget {
  const _WaitingForGuest({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.waitingForOpponent,
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
        const SizedBox(height: GebetaSpacing.lg),
        InkWell(
          borderRadius: GebetaRadius.card,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.copied)),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(GebetaSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: GebetaRadius.card,
              border: Border.all(color: GebetaColors.gold.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(l10n.roomCode, style: text.bodyMedium),
                const SizedBox(height: GebetaSpacing.sm),
                Text(
                  code,
                  style: text.displayLarge?.copyWith(
                    letterSpacing: 10,
                    color: GebetaColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: GebetaSpacing.md),
        Text(
          'Tap the code to copy it.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
      ],
    );
  }
}
