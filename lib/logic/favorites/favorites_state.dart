import 'package:equatable/equatable.dart';

/// Local favorites + recently-watched rooms, both keyed by room slug.
class FavoritesState extends Equatable {
  const FavoritesState({this.favorites = const {}, this.recents = const []});

  /// Slugs the viewer starred.
  final Set<String> favorites;

  /// Slugs of rooms the viewer opened, most-recent first.
  final List<String> recents;

  FavoritesState copyWith({Set<String>? favorites, List<String>? recents}) =>
      FavoritesState(
        favorites: favorites ?? this.favorites,
        recents: recents ?? this.recents,
      );

  @override
  List<Object?> get props => [favorites, recents];
}
