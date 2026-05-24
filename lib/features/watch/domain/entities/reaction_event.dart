import 'package:equatable/equatable.dart';

/// A floating emoji reaction sent by another viewer.
class ReactionEvent extends Equatable {
  const ReactionEvent({required this.emoji, required this.id, required this.name});

  final String emoji;

  /// Sender socket id (so concurrent reactions stay distinct).
  final String id;
  final String name;

  factory ReactionEvent.fromJson(Map<String, dynamic> json) => ReactionEvent(
    emoji: (json['emoji'] ?? '').toString(),
    id: json['id']?.toString() ?? '',
    name: (json['name'] ?? '').toString(),
  );

  @override
  List<Object?> get props => [emoji, id, name];
}
