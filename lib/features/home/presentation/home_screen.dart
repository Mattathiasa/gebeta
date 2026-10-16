import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../stats/data/stats_store.dart';
import '../../stats/domain/stats_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(playerStatsProvider);

    return Scaffold(
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: GebetaSpacing.page,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    l10n.homeTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: GebetaSpacing.xs),
                  Text(
                    'Traditional Ethiopian Mancala',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: GebetaSpacing.lg),
                  _StatsBar(stats: stats),
                  const SizedBox(height: GebetaSpacing.xl),
                  FilledButton(
                    onPressed: () => context.go(Routes.gameAi),
                    child: Text(l10n.playVsAi),
                  ),
                  const SizedBox(height: GebetaSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.lobby),
                    child: Text(l10n.playOnline),
                  ),
                  const SizedBox(height: GebetaSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.gameLocal),
                    child: Text(l10n.passAndPlay),
                  ),
                  const SizedBox(height: GebetaSpacing.md),
                  TextButton(
                    onPressed: () => context.go(Routes.tutorial),
                    child: Text(l10n.tutorial),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final AsyncValue<PlayerStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const SizedBox(height: 28),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) {
        if (s.gamesPlayed == 0) return const SizedBox(height: 28);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chip(context, '${s.wins}W', GebetaColors.win),
            const SizedBox(width: GebetaSpacing.sm),
            _chip(context, '${s.losses}L', GebetaColors.danger),
            const SizedBox(width: GebetaSpacing.sm),
            _chip(context, '${s.draws}D', GebetaColors.info),
          ],
        );
      },
    );
  }

  Widget _chip(BuildContext context, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GebetaSpacing.md,
          vertical: GebetaSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: GebetaRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
          child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      );
}

