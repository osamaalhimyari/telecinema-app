import 'package:equatable/equatable.dart';

/// Local UI state for the Favorites tab's source filter.
class FavoritesFilterState extends Equatable {
  const FavoritesFilterState({this.source});

  /// Active source filter: null = all, otherwise `cinemeta` / `egybest`.
  final String? source;

  FavoritesFilterState copyWith({String? source, bool clearSource = false}) {
    return FavoritesFilterState(
      source: clearSource ? null : (source ?? this.source),
    );
  }

  @override
  List<Object?> get props => [source];
}
