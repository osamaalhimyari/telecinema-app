import '../../domain/entities/chat_message.dart';
import '../../domain/entities/draw_event.dart';
import '../../domain/entities/playback_sync.dart';
import '../../domain/entities/presence_user.dart';
import '../../domain/entities/reaction_event.dart';
import '../../domain/entities/source_change.dart';
import '../../domain/entities/subtitle_settings.dart';
import '../../domain/entities/typing_event.dart';
import '../../domain/repositories/watch_repository.dart';
import '../datasources/watch_socket_datasource.dart';

class WatchRepositoryImpl implements WatchRepository {
  WatchRepositoryImpl(this._ds);

  final WatchSocketDataSource _ds;

  @override
  void join(String slug) => _ds.join(slug);
  @override
  void leave() => _ds.leave();

  @override
  Stream<PlaybackSync> get sync => _ds.sync;
  @override
  Stream<PlaybackSync> get forceResync => _ds.forceResync;
  @override
  Stream<List<ChatMessage>> get chatHistory => _ds.chatHistory;
  @override
  Stream<ChatMessage> get chat => _ds.chat;
  @override
  Stream<String?> get chatThrottled => _ds.chatThrottled;
  @override
  Stream<bool> get connected => _ds.connected;
  @override
  Stream<int> get viewerCount => _ds.viewerCount;
  @override
  Stream<List<PresenceUser>> get presence => _ds.presence;
  @override
  Stream<List<PresenceUser>> get waitState => _ds.waitState;
  @override
  Stream<SourceChange> get sourceChanged => _ds.sourceChanged;
  @override
  Stream<String> get subtitleChanged => _ds.subtitleChanged;
  @override
  Stream<SubtitleSettings> get subtitleSettings => _ds.subtitleSettings;
  @override
  Stream<ReactionEvent> get reaction => _ds.reaction;
  @override
  Stream<void> get roomDeleted => _ds.roomDeleted;
  @override
  Stream<VoiceEvent> get voice => _ds.voice;
  @override
  Stream<String> get voiceRead => _ds.voiceRead;
  @override
  Stream<DrawEvent> get draw => _ds.draw;
  @override
  Stream<TypingEvent> get typing => _ds.typing;

  @override
  void sendControl({required String action, double? currentTime, double? rate}) =>
      _ds.sendControl(action: action, currentTime: currentTime, rate: rate);
  @override
  void sendChat(String text, {String? clientId}) => _ds.sendChat(text, clientId: clientId);
  @override
  void sendReaction(String emoji) => _ds.sendReaction(emoji);
  @override
  void setBuffering(bool buffering) => _ds.setBuffering(buffering);
  @override
  void requestResync() => _ds.requestResync();
  @override
  void changeSource(String url) => _ds.changeSource(url);
  @override
  void setSubtitleSettings({double? offset, int? weight, int? size}) =>
      _ds.setSubtitleSettings(offset: offset, weight: weight, size: size);

  @override
  void voiceStart(String mimeType, String clipId) => _ds.voiceStart(mimeType, clipId);
  @override
  void voiceChunk(List<int> bytes) => _ds.voiceChunk(bytes);
  @override
  void voiceEnd(String clipId) => _ds.voiceEnd(clipId);
  @override
  void sendVoiceRead(String clipId) => _ds.sendVoiceRead(clipId);

  @override
  void sendDraw({
    required String strokeId,
    required String color,
    required List<List<double>> points,
    required bool done,
  }) => _ds.sendDraw(strokeId: strokeId, color: color, points: points, done: done);

  @override
  void sendTyping(bool typing) => _ds.sendTyping(typing);
}
