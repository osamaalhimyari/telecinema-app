import 'package:equatable/equatable.dart';

class NameDialogState extends Equatable {
  const NameDialogState({this.canSave = false});

  /// Whether the trimmed name is non-empty and the Save button is enabled.
  final bool canSave;

  NameDialogState copyWith({bool? canSave}) {
    return NameDialogState(canSave: canSave ?? this.canSave);
  }

  @override
  List<Object?> get props => [canSave];
}
