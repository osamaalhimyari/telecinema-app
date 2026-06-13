import 'package:equatable/equatable.dart';

/// Which local collection the grid is scoped to, on top of the search +
/// category filters held by [RoomsListCubit].
enum RoomsCollection { all, favorites, recent }

class RoomsViewState extends Equatable {
  const RoomsViewState({
    this.collection = RoomsCollection.all,
  });

  final RoomsCollection collection;

  RoomsViewState copyWith({
    RoomsCollection? collection,
  }) {
    return RoomsViewState(
      collection: collection ?? this.collection,
    );
  }

  @override
  List<Object?> get props => [collection];
}
