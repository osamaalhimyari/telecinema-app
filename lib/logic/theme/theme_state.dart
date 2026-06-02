import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class ThemeState extends Equatable {
  final ThemeMode mode;
  const ThemeState({this.mode = ThemeMode.dark});

  ThemeState copyWith({ThemeMode? mode}) => ThemeState(mode: mode ?? this.mode);

  @override
  List<Object?> get props => [mode];
}
