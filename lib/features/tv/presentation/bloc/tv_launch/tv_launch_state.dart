import 'package:equatable/equatable.dart';

class TvLaunchState extends Equatable {
  const TvLaunchState({this.busy = false, this.errorKey});

  /// True while a room is being created for a tapped channel.
  final bool busy;

  /// Set when room creation failed (a translatable key); consumed once by the
  /// page's listener to show a snackbar.
  final String? errorKey;

  TvLaunchState copyWith({bool? busy, String? errorKey, bool clearError = false}) {
    return TvLaunchState(
      busy: busy ?? this.busy,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [busy, errorKey];
}
