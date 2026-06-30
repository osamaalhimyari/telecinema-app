import 'package:equatable/equatable.dart';

/// Delivery state of a chat message. Only meaningful for messages this device
/// sent; anything received from the server is [sent].
enum ChatStatus { sending, sent, failed }

/// What a [ChatMessage] carries: plain [text], or a [voice] note (a recorded
/// audio clip relayed over the room, shown as a tap-to-play bubble).
enum MessageKind { text, voice }

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
    this.kind = MessageKind.text,
    this.audioPath,
    this.durationMs = 0,
    this.voiceRead = false,
    this.voicePlayed = false,
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

  /// Plain text vs a voice note.
  final MessageKind kind;

  /// For [MessageKind.voice]: the local file to play (our own recording when
  /// [mine], or the reassembled clip when received). Null until written.
  final String? audioPath;

  /// Voice clip length in ms (0 until probed).
  final int durationMs;

  /// Voice read receipt — for our own sent clips, true once a listener opened
  /// (played) it. Drives the double-check on the sender's bubble.
  final bool voiceRead;

  /// Whether *we* have already opened (played) this received voice clip — keeps
  /// us from re-sending the read receipt and dims the "new" marker.
  final bool voicePlayed;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);

  bool get isVoice => kind == MessageKind.voice;

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

  /// A voice note. [id] is the talk-burst `clipId` (used to match read
  /// receipts). Voice messages are local-only (never part of server chat
  /// history), so their status is always [ChatStatus.sent].
  factory ChatMessage.voice({
    required String id,
    required String name,
    required int ts,
    required bool mine,
    String? audioPath,
    int durationMs = 0,
    bool voiceRead = false,
    bool voicePlayed = false,
  }) => ChatMessage(
    id: id,
    name: name,
    text: '',
    ts: ts,
    mine: mine,
    kind: MessageKind.voice,
    audioPath: audioPath,
    durationMs: durationMs,
    voiceRead: voiceRead,
    voicePlayed: voicePlayed,
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
    MessageKind? kind,
    String? audioPath,
    int? durationMs,
    bool? voiceRead,
    bool? voicePlayed,
  }) => ChatMessage(
    id: id ?? this.id,
    name: name ?? this.name,
    text: text ?? this.text,
    ts: ts ?? this.ts,
    clientId: clientId ?? this.clientId,
    mine: mine ?? this.mine,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    audioPath: audioPath ?? this.audioPath,
    durationMs: durationMs ?? this.durationMs,
    voiceRead: voiceRead ?? this.voiceRead,
    voicePlayed: voicePlayed ?? this.voicePlayed,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    text,
    ts,
    clientId,
    mine,
    status,
    kind,
    audioPath,
    durationMs,
    voiceRead,
    voicePlayed,
  ];
}
