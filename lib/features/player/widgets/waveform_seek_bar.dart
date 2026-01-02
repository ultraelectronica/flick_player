import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';

class WaveformSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  // Cache the waveform data so it doesn't jitter on rebuilds
  late List<double> _waveformData;

  @override
  void initState() {
    super.initState();
    _generateWaveform();
  }

  @override
  void didUpdateWidget(WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration &&
        widget.duration.inMilliseconds > 0) {
      _generateWaveform();
    }
  }

  void _generateWaveform() {
    // Generate pseudo-random bar heights based on duration to be deterministic for the same song
    final random = Random(widget.duration.inMilliseconds);
    _waveformData = List.generate(
      60,
      (index) => 0.3 + random.nextDouble() * 0.7,
    );
  }

  void _startDrag(DragStartDetails details, BoxConstraints constraints) {
    _updatePosition(details.localPosition.dx, constraints);
  }

  void _updateDrag(DragUpdateDetails details, BoxConstraints constraints) {
    _updatePosition(details.localPosition.dx, constraints);
  }

  void _endDrag(DragEndDetails details, BoxConstraints constraints) {
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(widget.position);
    }
  }

  void _updatePosition(double dx, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final progress = (dx / width).clamp(0.0, 1.0);
    final newPosition = Duration(
      milliseconds: (progress * widget.duration.inMilliseconds).round(),
    );
    widget.onChanged(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragStart: (details) => _startDrag(details, constraints),
          onHorizontalDragUpdate: (details) =>
              _updateDrag(details, constraints),
          onHorizontalDragEnd: (details) => _endDrag(details, constraints),
          onTapDown: (details) => _startDrag(
            DragStartDetails(localPosition: details.localPosition),
            constraints,
          ),
          onTapUp: (details) {
            if (widget.onChangeEnd != null) {
              widget.onChangeEnd!(widget.position);
            }
          },
          behavior: HitTestBehavior.opaque, // touch anywhere in the area
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                waveformData: _waveformData,
                position: widget.position,
                duration: widget.duration,
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                activeColor: AppColors.accent,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Duration position;
  final Duration duration;
  final Color color;
  final Color activeColor;

  _WaveformPainter({
    required this.waveformData,
    required this.position,
    required this.duration,
    required this.color,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = waveformData.length;
    // Spacing between bars
    final spacing = 4.0;
    // Calculate total available width for bars (width - total spacing)
    final totalSpacing = (barCount - 1) * spacing;
    final barWidth = (size.width - totalSpacing) / barCount;

    final currentProgress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final barHeight = waveformData[i] * size.height;
      final x = i * (barWidth + spacing) + barWidth / 2;
      final yCenter = size.height / 2;

      // Check if this bar is "active" (played)
      // We can do a precise split within a bar if we want, but per-bar color is easier.
      // Let's do per-bar for simplicity first.
      final barProgress = i / barCount;
      final isPlayed = barProgress < currentProgress;

      paint.color = isPlayed ? activeColor : color;
      paint.strokeWidth = barWidth;

      // Draw line from center up and down
      canvas.drawLine(
        Offset(x, yCenter - barHeight / 2),
        Offset(x, yCenter + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.duration != duration;
  }
}
