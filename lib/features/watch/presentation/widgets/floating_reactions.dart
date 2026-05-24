import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/reaction_event.dart';

/// Overlays floating emoji that drift up and fade out, fed by the room's
/// reaction stream — the website's "reaction burst" effect.
class FloatingReactions extends StatefulWidget {
  const FloatingReactions({super.key, required this.stream});

  final Stream<ReactionEvent> stream;

  @override
  State<FloatingReactions> createState() => _FloatingReactionsState();
}

class _FloatingReactionsState extends State<FloatingReactions> {
  final _items = <_Floater>[];
  final _rand = Random();
  StreamSubscription<ReactionEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_spawn);
  }

  void _spawn(ReactionEvent e) {
    if (e.emoji.isEmpty || !mounted) return;
    final floater = _Floater(
      key: UniqueKey(),
      emoji: e.emoji,
      startDx: 0.1 + _rand.nextDouble() * 0.8,
      onDone: (key) => setState(() => _items.removeWhere((f) => f.key == key)),
    );
    setState(() => _items.add(floater));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Stack(children: _items));
  }
}

class _Floater extends StatefulWidget {
  const _Floater({
    required super.key,
    required this.emoji,
    required this.startDx,
    required this.onDone,
  });

  final String emoji;
  final double startDx;
  final void Function(Key key) onDone;

  @override
  State<_Floater> createState() => _FloaterState();
}

class _FloaterState extends State<_Floater> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone(widget.key!);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `Positioned.fill` must be a *direct* child of the overlay Stack. Wrapping
    // a `Positioned` in a `LayoutBuilder` inserts a RenderObject between it and
    // the Stack, which throws "Incorrect use of ParentDataWidget" and paints a
    // grey error box over the player. We position fractionally with `Align`
    // instead, so no layout constraints are needed.
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _c,
        child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
        builder: (context, child) {
          final t = _c.value;
          final yFromBottom = 0.12 + t * 0.7; // drifts up: 12% → 82% of height
          return Align(
            alignment: Alignment(widget.startDx * 2 - 1, 1 - 2 * yFromBottom),
            child: Transform.translate(
              offset: Offset(sin(t * pi * 2) * 14, 0), // gentle horizontal sway
              child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
            ),
          );
        },
      ),
    );
  }
}
