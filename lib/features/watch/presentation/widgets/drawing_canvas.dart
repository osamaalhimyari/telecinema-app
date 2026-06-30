import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/draw_mode/draw_mode_cubit.dart';
import '../bloc/draw_mode/draw_mode_state.dart';
import '../bloc/watch_cubit.dart';

/// The drawing input layer, shown over the video only while draw mode is on. It
/// captures touch strokes, streams them to the room (throttled, segment by
/// segment, so others see the line as it's drawn) and shows a color palette to
/// pick the pen. Rendering of every stroke — local and remote — is handled
/// separately by [DrawingOverlay] beneath it, so this widget paints nothing.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  String? _strokeId;
  final List<Offset> _pending = [];
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  /// Cap on how often a segment is relayed while dragging (~25/s).
  static const _throttle = Duration(milliseconds: 40);

  WatchCubit get _watch => context.read<WatchCubit>();

  Offset _norm(Offset p, Size size) => Offset(
    size.width == 0 ? 0 : (p.dx / size.width).clamp(0.0, 1.0),
    size.height == 0 ? 0 : (p.dy / size.height).clamp(0.0, 1.0),
  );

  void _start(Offset local, Size size) {
    _strokeId = _watch.newStrokeId();
    _pending
      ..clear()
      ..add(_norm(local, size));
    _flush(done: false);
  }

  void _update(Offset local, Size size) {
    if (_strokeId == null) return;
    _pending.add(_norm(local, size));
    if (DateTime.now().difference(_lastFlush) >= _throttle) _flush(done: false);
  }

  void _end() {
    if (_strokeId == null) return;
    _flush(done: true);
    _strokeId = null;
  }

  void _flush({required bool done}) {
    final id = _strokeId;
    if (id == null) return;
    if (_pending.isEmpty && !done) return;
    final colorHex = colorToHex(context.read<DrawModeCubit>().state.color);
    _watch.sendDraw(strokeId: id, color: colorHex, points: List.of(_pending), done: done);
    _pending.clear();
    _lastFlush = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final active = context.select<DrawModeCubit, bool>((c) => c.state.active);
    if (!active) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _start(d.localPosition, size),
                onPanUpdate: (d) => _update(d.localPosition, size),
                onPanEnd: (_) => _end(),
                onPanCancel: _end,
              ),
            ),
            // Anchored at the TOP, not the bottom, so it never covers the
            // subtitle/translation that sits along the bottom of the video.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(bottom: false, child: _palette(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _palette(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
        ),
        // A pan that starts on the palette must not also draw a line behind it.
        child: GestureDetector(
          onPanStart: (_) {},
          child: BlocBuilder<DrawModeCubit, DrawModeState>(
            buildWhen: (a, b) => a.color != b.color,
            builder: (context, state) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in kDrawPalette) ...[
                    _swatch(context, color, selected: color == state.color),
                    const SizedBox(width: 8),
                  ],
                  Container(width: 1, height: 22, color: Colors.white24),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => context.read<DrawModeCubit>().setActive(false),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _swatch(BuildContext context, Color color, {required bool selected}) {
    return GestureDetector(
      onTap: () => context.read<DrawModeCubit>().setColor(color),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
