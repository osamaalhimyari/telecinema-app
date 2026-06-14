import 'package:equatable/equatable.dart';

/// View state for the [UnlockOverlay]: just the password the user has typed so
/// far. The busy/error display reads [WatchState] instead — this only replaces
/// the dropped [TextEditingController].
class UnlockOverlayState extends Equatable {
  const UnlockOverlayState({this.password = ''});

  /// The password currently typed into the field.
  final String password;

  UnlockOverlayState copyWith({String? password}) {
    return UnlockOverlayState(password: password ?? this.password);
  }

  @override
  List<Object?> get props => [password];
}
