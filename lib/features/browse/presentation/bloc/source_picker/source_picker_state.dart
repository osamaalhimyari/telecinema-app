import 'package:equatable/equatable.dart';

class SourcePickerState extends Equatable {
  const SourcePickerState({this.loadingEp});

  /// `season x episode` key of the episode currently being resolved, or null.
  final String? loadingEp;

  SourcePickerState copyWith({
    String? loadingEp,
    bool clearLoadingEp = false,
  }) {
    return SourcePickerState(
      loadingEp: clearLoadingEp ? null : (loadingEp ?? this.loadingEp),
    );
  }

  @override
  List<Object?> get props => [loadingEp];
}
