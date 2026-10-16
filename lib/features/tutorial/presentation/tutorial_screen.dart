import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Three illustrated rules — sow, capture, win. Deliberately short:
/// the rest is learned by playing the easy bot.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tutorial)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _TutorialPage(
                    diagram: const _SowDiagram(),
                    title: 'Scoop & Sow',
                    body:
                        'Lift every seed from one of your pits and drop them '
                        'one by one into the next pits, moving forward. '
                        'Your row first, then your opponent\'s.',
                  ),
                  _TutorialPage(
                    diagram: const _CaptureDiagram(),
                    title: 'Capture Pairs & Threes',
                    body:
                        'If your last seed makes an opponent\'s pit hold '
                        'exactly 2 or 3 seeds, you take them — and keep '
                        'taking while the chain behind holds 2 or 3.',
                  ),
                  _TutorialPage(
                    diagram: const _WinDiagram(),
                    title: 'Collect 25 of 48',
                    body:
                        'The first to capture more than half the seeds wins. '
                        'You cannot make a move that leaves your opponent '
                        'with nothing — unless you have no choice.',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? GebetaColors.gold
                        : GebetaColors.wood.withValues(alpha: 0.3),
                    borderRadius: GebetaRadius.pill,
                  ),
                );
              }),
            ),
            Padding(
              padding: GebetaSpacing.page,
              child: FilledButton(
                onPressed: () {
                  if (_page < 2) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  } else {
                    context.go(Routes.gameAi);
                  }
                },
                child: Text(_page < 2 ? 'Next' : l10n.playVsAi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.diagram,
    required this.title,
    required this.body,
  });

  final Widget diagram;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: GebetaSpacing.page,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: diagram),
          const SizedBox(height: GebetaSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: GebetaSpacing.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

// --- tiny pit diagrams -------------------------------------------------

const _pit = 44.0;

Widget _pitDot(int seeds, {Color? glow}) => Container(
      width: _pit,
      height: _pit,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GebetaColors.woodDark,
        border: glow != null ? Border.all(color: glow, width: 2.5) : null,
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$seeds',
        style: const TextStyle(
          color: GebetaColors.seedLight,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

class _SowDiagram extends StatelessWidget {
  const _SowDiagram();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pitDot(0, glow: GebetaColors.honey),
        const SizedBox(width: 8),
        _pitDot(2),
        const SizedBox(width: 8),
        _pitDot(2),
        const SizedBox(width: 8),
        Transform.translate(
          offset: const Offset(0, -14),
          child: const Icon(Icons.arrow_upward, color: GebetaColors.gold),
        ),
      ],
    );
  }
}

class _CaptureDiagram extends StatelessWidget {
  const _CaptureDiagram();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pitDot(2, glow: GebetaColors.gold),
        const SizedBox(width: 8),
        _pitDot(3, glow: GebetaColors.gold),
        const SizedBox(width: 8),
        _pitDot(4),
        const SizedBox(width: 12),
        const Icon(Icons.east, color: GebetaColors.gold),
        const SizedBox(width: 12),
        const Text('🔥', style: TextStyle(fontSize: 28)),
      ],
    );
  }
}

class _WinDiagram extends StatelessWidget {
  const _WinDiagram();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pitDot(25, glow: GebetaColors.win),
        const SizedBox(width: 12),
        Text(
          '> 24',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: GebetaColors.win,
              ),
        ),
      ],
    );
  }
}
