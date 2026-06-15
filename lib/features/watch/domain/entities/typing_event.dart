import 'package:equatable/equatable.dart';

/// A relayed "is writing…" signal from another viewer. [typing] is false when
/// they stopped (sent on send, blur, leave or disconnect). [id] is the sender's
/// socket id so concurrent typers stay distinct.
class TypingEvent extends Equatable {
  const TypingEvent({required this.id, required this.name, required this.typing});

  final String id;
  final String name;
  final bool typing;

  factory TypingEvent.fromJson(Map<String, dynamic> json) => TypingEvent(
    id: json['id']?.toString() ?? '',
    name: (json['name'] ?? '').toString(),
    typing: json['typing'] == true,
  );

  @override
  List<Object?> get props => [id, name, typing];
}
