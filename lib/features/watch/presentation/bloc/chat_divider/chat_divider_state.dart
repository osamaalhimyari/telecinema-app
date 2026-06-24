import 'package:equatable/equatable.dart';

class ChatDividerState extends Equatable {
  const ChatDividerState({this.fraction = 0.35});

  final double fraction;

  ChatDividerState copyWith({double? fraction}) =>
      ChatDividerState(fraction: fraction ?? this.fraction);

  @override
  List<Object?> get props => [fraction];
}
