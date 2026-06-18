import 'dart:async';

import 'package:flutter/material.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/user_avatar.dart';
import '../../domain/entities/presence_notice.dart';

/// Transient "X joined / left" pills that drop in at the top of the player,
/// linger, then fade out — like a chat message appearing and disappearing.
/// Fed by `WatchCubit.presenceNotices`; pointer-transparent so it never blocks
/// the video. Shared by the portrait player, the fullscreen view and PiP.
class PresenceNotices extends StatefulWidget {
  const PresenceNotices({super.key, required this.stream});

  final Stream<PresenceNotice> stream;

  @override
  State<PresenceNotices> createState() => _PresenceNoticesState();
}

class _PresenceNoticesState extends State<PresenceNotices> {
  static const _maxVisible = 3;
  final _items = <_NoticePill>[];
  StreamSubscription<PresenceNotice>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_add);
  }

  void _add(PresenceNotice n) {
    if (!mounted || n.name.trim().isEmpty) return;
    setState(() {
      _items.add(_NoticePill(key: UniqueKey(), notice: n, onDone: _remove));
      if (_items.length > _maxVisible) _items.removeAt(0);
    });
  }

  void _remove(Key key) {
    if (mounted) setState(() => _items.removeWhere((p) => p.key == key));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _items,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticePill extends StatefulWidget {
  const _NoticePill({required super.key, required this.notice, required this.onDone});

  final PresenceNotice notice;
  final void Function(Key key) onDone;

  @override
  State<_NoticePill> createState() => _NoticePillState();
}

class _NoticePillState extends State<_NoticePill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
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

  double get _opacity {
    final t = _c.value;
    if (t < 0.08) return t / 0.08; // fade in
    if (t > 0.85) return (1 - t) / 0.15; // fade out
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final verb = context.tr(n.joined ? TranslationKeys.userJoined : TranslationKeys.userLeft);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(opacity: _opacity.clamp(0.0, 1.0), child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(name: n.name, size: 18),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${n.name} ',
                    style: TextStyle(
                      color: userColorFor(n.name),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  TextSpan(
                    text: verb,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
