import 'package:equatable/equatable.dart';

/// One chat message inside a room (server-stamped id + timestamp).
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.name,
    required this.text,
    required this.ts,
  });

  final String id;
  final String name;
  final String text;

  /// ms since epoch.
  final int ts;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '${json['ts']}-${json['name']}',
    name: (json['name'] ?? 'Anonymous').toString(),
    text: (json['text'] ?? '').toString(),
    ts: json['ts'] is num ? (json['ts'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
  );

  @override
  List<Object?> get props => [id, name, text, ts];
}
