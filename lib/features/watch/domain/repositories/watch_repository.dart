import '../../data/datasources/watch_socket_datasource.dart';
import '../entities/chat_message.dart';
import '../entities/playback_sync.dart';
import '../entities/presence_user.dart';
import '../entities/reaction_event.dart';
import '../entities/source_change.dart';
import '../entities/subtitle_settings.dart';

/// The realtime room contract. Streams surface server events; the `send*`
/// methods relay user intent. Transport health is observed separately via the
/// global `SocketCubit`, so these don't return `Either`.
abstract class WatchRepository {
  void join(String slug);
  void leave();

  Stream<PlaybackSync> get sync;
  Stream<PlaybackSync> get forceResync;
  Stream<List<ChatMessage>> get chatHistory;
  Stream<ChatMessage> get chat;
  Stream<String?> get chatThrottled;

  /// Socket connectivity transitions — drives the chat outbox flush on reconnect.
  Stream<bool> get connected;
  Stream<int> get viewerCount;
  Stream<List<PresenceUser>> get presence;
  Stream<List<PresenceUser>> get waitState;
  Stream<SourceChange> get sourceChanged;
  Stream<String> get subtitleChanged;
  Stream<SubtitleSettings> get subtitleSettings;
  Stream<ReactionEvent> get reaction;
  Stream<void> get roomDeleted;
  Stream<VoiceEvent> get voice;

  void sendControl({required String action, double? currentTime, double? rate});
  void sendChat(String text, {String? clientId});
  void sendReaction(String emoji);
  void setBuffering(bool buffering);
  void requestResync();
  void changeSource(String url);
  void setSubtitleSettings({double? offset, int? weight, int? size});

  void voiceStart(String mimeType);
  void voiceChunk(List<int> bytes);
  void voiceEnd();
}
