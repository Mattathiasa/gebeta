import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Four illustrated rules — sow, capture, starvation, win. Deliberately
/// short: the rest is learned by playing the easy bot.
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
                children: const [
                  _TutorialPage(
                    diagram: _SowDiagram(),
                    title: 'Pick a Pit, Sow It Empty',
                    body:
                        'Tap one of your pits. Every seed in it drops into '
                        'the pits ahead, one seed each, going around the '
                        'board — your row, then your opponent\'s.',
                  ),
                  _TutorialPage(
                    diagram: _CaptureDiagram(),
                    title: 'Land on 2 or 3, Take It',
                    body:
                        'If your last seed lands in an opponent\'s pit and '
                        'that pit now holds 2 or 3 seeds, you capture it. '
                        'Keep stepping backward, capturing each pit behind '
                        'it that also has 2 or 3.',
                  ),
                  _TutorialPage(
                    diagram: _StarveDiagram(),
                    title: 'Never Leave Them Empty',
                    body:
                        'A move that would leave your opponent with zero '
                        'seeds on their whole side is not allowed — unless '
                        'it\'s truly your only option.',
                  ),
                  _TutorialPage(
                    diagram: _WinDiagram(),
                    title: 'First to 25 Wins',
                    body:
                        'There are 48 seeds on the board. Capture more than '
                        'half of them — 25 or more — before your opponent '
                        'does, and you win.',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
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
                  if (_page < 3) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  } else {
                    context.go(Routes.gameAi);
                  }
                },
                child: Text(_page < 3 ? 'Next' : l10n.playVsAi),
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

/// Small caption under a diagram pit, e.g. "pick this" or "1st".
Widget _caption(String text, {Color color = GebetaColors.inkSoft}) => Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );

Widget _arrowRight({Color color = GebetaColors.gold}) =>
    Icon(Icons.arrow_forward, color: color, size: 20);

class _SowDiagram extends StatelessWidget {
  const _SowDiagram();

  @override
  Widget build(BuildContext context) {
    // Before: a full pit about to be lifted, three empty pits ahead.
    // After: the origin is empty, each pit ahead gained one seed.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(children: [_pitDot(3, glow: GebetaColors.honey), _caption('pick up')]),
            const SizedBox(width: 10),
            _arrowRight(),
            const SizedBox(width: 10),
            Column(children: [_pitDot(1), _caption('+1')]),
            const SizedBox(width: 10),
            Column(children: [_pitDot(1), _caption('+1')]),
            const SizedBox(width: 10),
            Column(children: [_pitDot(1), _caption('+1')]),
          ],
        ),
        const SizedBox(height: GebetaSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(children: [_pitDot(0), _caption('empty')]),
            const SizedBox(width: 10 + 20 + 10),
            Column(children: [_pitDot(2), _caption('')]),
            const SizedBox(width: 10),
            Column(children: [_pitDot(2), _caption('')]),
            const SizedBox(width: 10),
            Column(children: [_pitDot(2), _caption('')]),
          ],
        ),
      ],
    );
  }
}

class _CaptureDiagram extends StatelessWidget {
  const _CaptureDiagram();

  @override
  Widget build(BuildContext context) {
    // The chain walks backward: last-sown pit captures first (step 1),
    // then the walk steps back and captures step 2, and stops at a pit
    // that isn't 2 or 3.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(children: [_pitDot(4), _caption('stops here')]),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_back, color: GebetaColors.inkSoft, size: 18),
        const SizedBox(width: 10),
        Column(
          children: [_pitDot(3, glow: GebetaColors.gold), _caption('2nd', color: GebetaColors.goldDeep)],
        ),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_back, color: GebetaColors.gold, size: 18),
        const SizedBox(width: 10),
        Column(
          children: [_pitDot(2, glow: GebetaColors.gold), _caption('1st · last seed', color: GebetaColors.goldDeep)],
        ),
      ],
    );
  }
}

class _StarveDiagram extends StatelessWidget {
  const _StarveDiagram();

  @override
  Widget build(BuildContext context) {
    // A legal move (opponent keeps seeds) vs. an illegal one (wipes them out).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: GebetaColors.win, size: 20),
            const SizedBox(width: 8),
            _pitDot(1, glow: GebetaColors.win),
            const SizedBox(width: 6),
            _pitDot(2, glow: GebetaColors.win),
            const SizedBox(width: 6),
            _pitDot(0),
            const SizedBox(width: 12),
            _caption('opponent keeps seeds'),
          ],
        ),
        const SizedBox(height: GebetaSpacing.md),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel, color: GebetaColors.danger, size: 20),
            const SizedBox(width: 8),
            _pitDot(0, glow: GebetaColors.danger),
            const SizedBox(width: 6),
            _pitDot(0, glow: GebetaColors.danger),
            const SizedBox(width: 6),
            _pitDot(0, glow: GebetaColors.danger),
            const SizedBox(width: 12),
            _caption('wipes them out — not allowed'),
          ],
        ),
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
          'of 48',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: GebetaColors.win,
              ),
        ),
      ],
    );
  }
}
