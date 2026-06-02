import 'dart:async';

import 'package:flutter/material.dart';

import '/core/shared/user_avatar.dart';
import '../../domain/entities/chat_message.dart';

/// Live chat overlay for the fullscreen player: each incoming message floats in
/// at the bottom-left, lingers, then fades out — so viewers can follow the chat
/// without the (hidden) messages panel. Fed by `WatchCubit.incomingChat`.
class FloatingChatOverlay extends StatefulWidget {
  const FloatingChatOverlay({super.key, required this.stream});

  final Stream<ChatMessage> stream;

  @override
  State<FloatingChatOverlay> createState() => _FloatingChatOverlayState();
}

class _FloatingChatOverlayState extends State<FloatingChatOverlay> {
  static const _maxVisible = 5;
  final _items = <_ChatBubble>[];
  StreamSubscription<ChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_add);
  }

  void _add(ChatMessage m) {
    if (!mounted || m.text.isEmpty) return;
    setState(() {
      _items.add(_ChatBubble(key: UniqueKey(), message: m, onDone: _remove));
      if (_items.length > _maxVisible) _items.removeAt(0);
    });
  }

  void _remove(Key key) {
    if (mounted) setState(() => _items.removeWhere((b) => b.key == key));
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
          alignment: Alignment.bottomLeft,
          child: Padding(
            // Sit above the player controls / progress bar.
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _items,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  const _ChatBubble({required super.key, required this.message, required this.onDone});

  final ChatMessage message;
  final void Function(Key key) onDone;

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5500),
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
    if (t < 0.06) return t / 0.06; // fade in
    if (t > 0.9) return (1 - t) / 0.1; // fade out
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(opacity: _opacity.clamp(0.0, 1.0), child: child),
      child: Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${widget.message.name}  ',
                style: TextStyle(
                  color: userColorFor(widget.message.name),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: widget.message.text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
