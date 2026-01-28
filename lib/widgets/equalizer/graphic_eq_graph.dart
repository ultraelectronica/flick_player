import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/providers/equalizer_provider.dart';

class GraphicEqGraph extends ConsumerWidget {
  const GraphicEqGraph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Avoid wide rebuilds; repaint is driven by the controller.
    final repaint = ref.watch(eqGraphRepaintControllerProvider);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _GraphicEqGraphPainter(
          context: context,
          ref: ref,
          repaint: repaint,
        ),
      ),
    );
  }
}

class _GraphicEqGraphPainter extends CustomPainter {
  final BuildContext context;
  final WidgetRef ref;

  _GraphicEqGraphPainter({
    required this.context,
    required this.ref,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const double _minHz = 20.0;
  static const double _maxHz = 20000.0;

  static const double _minDb = -12.0;
  static const double _maxDb = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(AppConstants.radiusMd),
    );

    // Background overlay to help legibility inside glass cards.
    final bgPaint = Paint()
      ..color = AppColors.glassBackgroundStrong.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    _drawGrid(canvas, size);
    _drawCurve(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.glassBorder.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5),
        const Radius.circular(AppConstants.radiusMd),
      ),
      gridPaint,
    );

    final dbLines = <double>[-12, -6, 0, 6, 12];
    for (final db in dbLines) {
      final y = _dbToY(db, size.height);
      final paint = Paint()
        ..color = db == 0
            ? AppColors.glassBorderStrong.withValues(alpha: 0.8)
            : AppColors.glassBorder.withValues(alpha: 0.35)
        ..strokeWidth = db == 0 ? 1.2 : 1.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // A few log-frequency guide lines.
    const freqs = <double>[
      20,
      50,
      100,
      200,
      500,
      1000,
      2000,
      5000,
      10000,
      20000,
    ];
    for (final hz in freqs) {
      final x = _hzToX(hz, size.width);
      final paint = Paint()
        ..color = AppColors.glassBorder.withValues(alpha: 0.25)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawCurve(Canvas canvas, Size size) {
    final enabled = ref.read(eqEnabledProvider);
    final freqs = EqualizerState.defaultGraphicFrequenciesHz;
    final gains = List<double>.generate(
      freqs.length,
      (i) => ref.read(eqGraphicGainDbProvider(i)),
      growable: false,
    );

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = enabled
          ? AdaptiveColorProvider.textPrimary(context).withValues(alpha: 0.90)
          : AdaptiveColorProvider.textTertiary(context).withValues(alpha: 0.70);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = enabled
          ? AdaptiveColorProvider.textPrimary(context).withValues(alpha: 0.12)
          : AdaptiveColorProvider.textTertiary(context).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();
    final sampleCount = math.max(64, size.width.floor());

    for (var i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      final hz = _tToHz(t);
      final db = enabled ? _interpDbAtHz(hz, freqs, gains) : 0.0;
      final x = t * size.width;
      final y = _dbToY(db, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);

    // Band control points
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = enabled
          ? AdaptiveColorProvider.textPrimary(context).withValues(alpha: 0.75)
          : AdaptiveColorProvider.textTertiary(context).withValues(alpha: 0.55);

    for (var i = 0; i < freqs.length; i++) {
      final x = _hzToX(freqs[i], size.width);
      final y = _dbToY(enabled ? gains[i] : 0.0, size.height);
      canvas.drawCircle(Offset(x, y), 3.0, pointPaint);
    }
  }

  // Linear interpolation in log-frequency space between the nearest bands.
  double _interpDbAtHz(double hz, List<double> freqs, List<double> gains) {
    final clampedHz = hz.clamp(freqs.first, freqs.last).toDouble();
    final logHz = math.log(clampedHz);

    // Find the segment [i, i+1] that contains hz.
    var i = 0;
    while (i < freqs.length - 2 && clampedHz > freqs[i + 1]) {
      i++;
    }

    final f0 = freqs[i];
    final f1 = freqs[i + 1];
    final g0 = gains[i];
    final g1 = gains[i + 1];

    final t = ((logHz - math.log(f0)) / (math.log(f1) - math.log(f0))).clamp(
      0.0,
      1.0,
    );
    final db = g0 + (g1 - g0) * t;
    return db.clamp(_minDb, _maxDb).toDouble();
  }

  double _dbToY(double db, double height) {
    final t = ((db - _minDb) / (_maxDb - _minDb)).clamp(0.0, 1.0);
    return height * (1.0 - t);
  }

  double _hzToX(double hz, double width) {
    final t = (_hzToT(hz)).clamp(0.0, 1.0);
    return t * width;
  }

  double _hzToT(double hz) {
    final clamped = hz.clamp(_minHz, _maxHz).toDouble();
    final logMin = math.log(_minHz);
    final logMax = math.log(_maxHz);
    return (math.log(clamped) - logMin) / (logMax - logMin);
  }

  double _tToHz(double t) {
    final logMin = math.log(_minHz);
    final logMax = math.log(_maxHz);
    final v = logMin + (logMax - logMin) * t.clamp(0.0, 1.0);
    return math.exp(v);
  }

  @override
  bool shouldRepaint(covariant _GraphicEqGraphPainter oldDelegate) {
    // Repaint is driven by [repaint] listenable.
    return false;
  }
}
