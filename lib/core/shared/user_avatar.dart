import 'package:flutter/material.dart';

/// Per-user display color + a small initial avatar, shared by chat (sender
/// names) and the floating reaction overlay (avatar under the emoji).
///
/// The color is derived deterministically from the display name with an
/// explicit hash (not `String.hashCode`, which is seed-randomized per run), so
/// every client paints the same user the same color.

const List<Color> _palette = <Color>[
  Color(0xFFEF5350), // red
  Color(0xFFEC407A), // pink
  Color(0xFFAB47BC), // purple
  Color(0xFF7E57C2), // deep purple
  Color(0xFF5C6BC0), // indigo
  Color(0xFF42A5F5), // blue
  Color(0xFF29B6F6), // light blue
  Color(0xFF26C6DA), // cyan
  Color(0xFF26A69A), // teal
  Color(0xFF66BB6A), // green
  Color(0xFF9CCC65), // light green
  Color(0xFFFFA726), // orange
  Color(0xFFFF7043), // deep orange
  Color(0xFF8D6E63), // brown
];

/// A stable, theme-agnostic color for [name]. Mid-tone palette so it reads on
/// both light surfaces and the dark fullscreen overlay.
Color userColorFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return _palette.first;
  var hash = 0;
  for (final code in trimmed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}

/// A small circular avatar showing the sender's first initial on their
/// [userColorFor] color. Used beneath floating reaction emoji.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.size = 22});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: userColorFor(name),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
