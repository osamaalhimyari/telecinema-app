import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/entities/draw_event.dart';
import '../bloc/draw_mode/draw_mode_cubit.dart' show hexToColor;

/// Renders the room's ephemeral drawings over the video. Strokes arrive segment
/// by segment via [stream] (both relayed strokes and this device's local echo);
/// each line appears as it's drawn, lingers once finished, then fades out
/// **in place** — static, never drifting (unlike [FloatingReactions]).
///
/// Render-only: wrapped in [IgnorePointer] so it never blocks the video or the
/// drawing canvas above it.
class DrawingOverlay extends StatefulWidget {
  const DrawingOverlay({super.key, required this.stream});

  final Stream<DrawEvent> stream;

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> with SingleTickerProviderStateMixin {
  /// Active strokes keyed by `senderId:strokeId`.
  final Map<String, _Stroke> _strokes = {};
  late final Ticker _ticker = createTicker(_onTick);
  StreamSubscription<DrawEvent>? _sub;

  /// How long a finished stroke stays solid, then how long it fades.
  static const _lingerMs = 1800;
  static const _fadeMs = 800;

  /// Safety: an unfinished stroke (its `done` segment was lost) is dropped after
  /// this so it can't linger forever.
  static const _maxAliveMs = 10000;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_onEvent);
  }

  void _onEvent(DrawEvent e) {
    if (!mounted || e.strokeId.isEmpty) return;
    final stroke = _strokes.putIfAbsent(e.key, () => _Stroke(hexToColor(e.color)));
    stroke.points.addAll(e.points);
    if (e.done) stroke.doneAt ??= DateTime.now();
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    _strokes.removeWhere((_, s) {
      if (s.doneAt != null) return now.difference(s.doneAt!).inMilliseconds > _lingerMs + _fadeMs;
      return now.difference(s.createdAt).inMilliseconds > _maxAliveMs;
    });
    if (_strokes.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _StrokePainter(List.of(_strokes.values), DateTime.now()),
      ),
    );
  }
}

class _Stroke {
  _Stroke(this.color);

  final Color color;
  final List<Offset> points = []; // normalized 0..1
  final DateTime createdAt = DateTime.now();
  DateTime? doneAt;
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes, this.now);

  final List<_Stroke> strokes;
  final DateTime now;

  static const _lingerMs = 1800;
  static const _fadeMs = 800;

  double _opacity(_Stroke s) {
    if (s.doneAt == null) return 1;
    final e = now.difference(s.doneAt!).inMilliseconds;
    if (e <= _lingerMs) return 1;
    return (1 - (e - _lingerMs) / _fadeMs).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final opacity = _opacity(s);
      if (opacity <= 0) continue;
      final paint = Paint()
        ..color = s.color.withValues(alpha: opacity)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      Offset scale(Offset p) => Offset(p.dx * size.width, p.dy * size.height);

      if (s.points.length == 1) {
        // A tap with no drag — render a dot.
        canvas.drawCircle(scale(s.points.first), 2.4, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(scale(s.points.first).dx, scale(s.points.first).dy);
      for (var i = 1; i < s.points.length; i++) {
        final p = scale(s.points[i]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}
