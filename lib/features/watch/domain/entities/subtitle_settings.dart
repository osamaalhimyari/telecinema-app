import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show FontWeight;

/// The room's **shared** subtitle display settings — synchronized across every
/// client exactly like the subtitle file itself. Any viewer can change them
/// (over `set_subtitle_settings`); the server clamps, persists and rebroadcasts
/// them as `subtitle_settings_changed`.
///
///  * [offset] — seconds to shift the cues. Positive shows them **later** (use
///    when the subtitle runs ahead of the scene), negative shows them
///    **earlier**. Clamped to [-60, 60], stepped at 0.1 s.
///  * [weight] — font weight, 100..900 (maps to [FontWeight]); 500 = default.
///  * [size]   — font size in logical pixels; 16 = default.
class SubtitleSettings extends Equatable {
  const SubtitleSettings({this.offset = 0, this.weight = 500, this.size = 28});

  const SubtitleSettings.defaults() : this();

  final double offset;
  final int weight;
  final int size;

  /// The [weight] (100..900) as a Flutter [FontWeight]. `FontWeight.values` is
  /// ordered w100..w900, so the index is `weight / 100 - 1`.
  FontWeight get fontWeight {
    final index = (weight ~/ 100 - 1).clamp(0, FontWeight.values.length - 1);
    return FontWeight.values[index];
  }

  SubtitleSettings copyWith({double? offset, int? weight, int? size}) => SubtitleSettings(
    offset: offset ?? this.offset,
    weight: weight ?? this.weight,
    size: size ?? this.size,
  );

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) => SubtitleSettings(
    offset: _d(json['offset']),
    weight: _i(json['weight'], 500),
    size: _i(json['size'], 28),
  );

  static double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int _i(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  List<Object?> get props => [offset, weight, size];
}
