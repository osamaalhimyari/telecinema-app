import 'package:equatable/equatable.dart';

class SettingsSheetState extends Equatable {
  const SettingsSheetState({
    this.serverError,
    this.isServerDefault = false,
  });

  /// Validation error for the server field, or null when valid.
  final String? serverError;

  /// Whether the current server field value equals the built-in default
  /// (drives the reset button's enablement).
  final bool isServerDefault;

  SettingsSheetState copyWith({
    String? serverError,
    bool? isServerDefault,
    bool clearServerError = false,
  }) {
    return SettingsSheetState(
      serverError: clearServerError ? null : (serverError ?? this.serverError),
      isServerDefault: isServerDefault ?? this.isServerDefault,
    );
  }

  @override
  List<Object?> get props => [serverError, isServerDefault];
}
