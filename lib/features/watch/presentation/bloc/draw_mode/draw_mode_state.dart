import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart' show Color;

/// UI state for the on-video drawing tool: whether draw mode is engaged and the
/// currently selected pen color. Shared by the portrait and fullscreen players
/// so the choice carries across them.
class DrawModeState extends Equatable {
  const DrawModeState({this.active = false, this.color = const Color(0xFFFF5252)});

  /// True while the user is in draw mode (the canvas captures touches).
  final bool active;

  /// The selected pen color.
  final Color color;

  DrawModeState copyWith({bool? active, Color? color}) =>
      DrawModeState(active: active ?? this.active, color: color ?? this.color);

  @override
  List<Object?> get props => [active, color];
}
