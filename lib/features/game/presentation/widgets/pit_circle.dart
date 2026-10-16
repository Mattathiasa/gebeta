import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// One carved pit. Shows its seeds as dots (with a count when crowded)
/// and three visual states: legal move (glowing ring), mid-sow
/// highlight (gold fill), and capture flash (emptying).
class PitCircle extends StatelessWidget {
  const PitCircle({
    super.key,
    required this.seeds,
    required this.size,
    this.isLegal = false,
    this.isHighlighted = false,
    this.isCaptured = false,
    this.onTap,
  });

  final int seeds;
  final double size;
  final bool isLegal;
  final bool isHighlighted;
  final bool isCaptured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isHighlighted
        ? GebetaColors.honey
        : isCaptured
            ? GebetaColors.gold.withValues(alpha: 0.35)
            : GebetaColors.woodDark;

    return GestureDetector(
      onTap: isLegal ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
            if (isLegal)
              BoxShadow(
                color: GebetaColors.gold.withValues(alpha: 0.85),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
          border: isLegal
              ? Border.all(color: GebetaColors.gold, width: 2.5)
              : null,
        ),
        child: seeds > 0
            ? _Seeds(count: seeds, size: size)
            : Center(
                child: Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Seeds extends StatelessWidget {
  const _Seeds({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final seedSize = size * 0.16;

    if (count > 6) {
      // Crowded pit: fewer dots + a number so counts stay readable.
      return Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: size * 0.03,
              runSpacing: size * 0.03,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < 6; i++) _dot(_color(i), seedSize),
              ],
            ),
            SizedBox(height: size * 0.03),
            Text(
              '$count',
              style: TextStyle(
                color: GebetaColors.seedLight,
                fontSize: size * 0.2,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    // Few seeds: ring arrangement inside the pit.
    final radius = size * 0.2;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Transform.translate(
            offset: count == 1
                ? Offset.zero
                : Offset(
                    radius * math.cos(i * 2 * math.pi / count),
                    radius * math.sin(i * 2 * math.pi / count),
                  ),
            child: _dot(_color(i), seedSize),
          ),
      ],
    );
  }

  static Color _color(int i) =>
      i.isEven ? GebetaColors.seedLight : GebetaColors.honey;

  Widget _dot(Color color, double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.9,
            colors: [
              color.withValues(alpha: 0.95),
              color.withValues(alpha: 0.65),
            ],
          ),
        ),
      );
}
