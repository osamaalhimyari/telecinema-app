import 'package:equatable/equatable.dart';

/// Delivery state of a chat message. Only meaningful for messages this device
/// sent; anything received from the server is [sent].
enum ChatStatus { sending, sent, failed }

/// One chat message inside a room (server-stamped id + timestamp).
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.name,
    required this.text,
    required this.ts,
    this.clientId,
    this.mine = false,
    this.status = ChatStatus.sent,
  });

  final String id;
  final String name;
  final String text;

  /// ms since epoch.
  final int ts;

  /// Client-generated nonce for messages this device originated. Echoed back by
  /// the server so we can reconcile the optimistic bubble with its delivered
  /// copy (and so the server can drop a duplicate re-send). Null for messages
  /// received from other people.
  final String? clientId;

  /// True for messages this device sent — drives right-alignment and the
  /// delivery indicator, independent of the (possibly duplicated) display name.
  final bool mine;

  /// Outgoing delivery state; received messages are always [ChatStatus.sent].
  final ChatStatus status;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);

  /// Still on its way (or failed) — i.e. not yet confirmed by the server.
  bool get isPending => status != ChatStatus.sent;

  /// Builds the optimistic bubble shown the instant the user hits send, before
  /// the server confirms it. [id] doubles as the [clientId] until delivery.
  factory ChatMessage.local({
    required String clientId,
    required String name,
    required String text,
    required int ts,
  }) => ChatMessage(
    id: clientId,
    clientId: clientId,
    name: name,
    text: text,
    ts: ts,
    mine: true,
    status: ChatStatus.sending,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '${json['ts']}-${json['name']}',
    name: (json['name'] ?? 'Anonymous').toString(),
    text: (json['text'] ?? '').toString(),
    ts: json['ts'] is num ? (json['ts'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    clientId: json['clientId']?.toString(),
  );

  ChatMessage copyWith({
    String? id,
    String? name,
    String? text,
    int? ts,
    String? clientId,
    bool? mine,
    ChatStatus? status,
  }) => ChatMessage(
    id: id ?? this.id,
    name: name ?? this.name,
    text: text ?? this.text,
    ts: ts ?? this.ts,
    clientId: clientId ?? this.clientId,
    mine: mine ?? this.mine,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [id, name, text, ts, clientId, mine, status];
}
