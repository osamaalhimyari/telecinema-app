import 'package:flutter/painting.dart' show Color;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'draw_mode_state.dart';

/// The pen colors offered while drawing on the video.
const List<Color> kDrawPalette = [
  Color(0xFFFF5252), // red
  Color(0xFFFF9800), // orange
  Color(0xFFFFEB3B), // yellow
  Color(0xFF69F0AE), // green
  Color(0xFF40C4FF), // blue
  Color(0xFFE040FB), // purple
  Color(0xFFFFFFFF), // white
  Color(0xFF000000), // black
];

/// `Color` → `#RRGGBB` for the wire. Uses the 0..1 component API (same era as
/// `Color.withValues`, already used across this app).
String colorToHex(Color c) {
  String h(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// `#RRGGBB` (or `#AARRGGBB`) → `Color`; falls back to white on a bad string.
Color hexToColor(String hex) {
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'ff$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? const Color(0xFFFFFFFF) : Color(v);
}

/// Owns draw-mode on/off and the selected pen color. Page-scoped and shared
/// between the portrait room and the fullscreen player (provided once, handed
/// to fullscreen via `BlocProvider.value`).
class DrawModeCubit extends Cubit<DrawModeState> {
  DrawModeCubit() : super(const DrawModeState());

  void toggle() => emit(state.copyWith(active: !state.active));

  void setActive(bool active) => emit(state.copyWith(active: active));

  /// Picking a color also engages draw mode — that's the intent of tapping one.
  void setColor(Color color) => emit(state.copyWith(color: color, active: true));
}
