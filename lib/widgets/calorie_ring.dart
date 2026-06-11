import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Hedefe göre tüketilen kaloriyi gösteren, yuvarlak uçlu dairesel gösterge.
/// Ortada kalan kalori, halka dolumu = yenen / hedef. Koyu temada hafif parlama.
class CalorieRing extends StatelessWidget {
  final double consumed;
  final int goal;

  const CalorieRing({super.key, required this.consumed, required this.goal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final remaining = (goal - consumed).round();
    final over = consumed > goal;
    final fmt = NumberFormat.decimalPattern('tr');

    final ringColor = over
        ? scheme.error
        : (isDark ? AppColors.accentDark : AppColors.accentLight);

    return SizedBox(
      width: 230,
      height: 230,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          trackColor: ringColor.withValues(alpha: 0.12),
          progressColor: ringColor,
          glow: isDark,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                over
                    ? '+${fmt.format(-remaining)}'
                    : fmt.format(remaining),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: scheme.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                over ? 'kcal aşıldı' : 'kcal kaldı',
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final bool glow;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final center = (Offset.zero & size).center;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweep = progress * 2 * math.pi;

    // Koyu temada parlama: önce bulanık bir alt katman çiz.
    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = progressColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, glowPaint);
    }

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor ||
      old.glow != glow;
}
