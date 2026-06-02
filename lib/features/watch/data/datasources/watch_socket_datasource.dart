import 'dart:async';
import 'dart:typed_data';

import '/core/config/app_config.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/socket/socket_cubit.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/playback_sync.dart';
import '../../domain/entities/presence_user.dart';
import '../../domain/entities/reaction_event.dart';
import '../../domain/entities/source_change.dart';
import '../../domain/entities/subtitle_settings.dart';

/// Binds the shared [SocketCubit] to a single room's realtime protocol — the
/// exact event set the website uses (`join_room`, `sync`, `control`, `chat`,
/// `room_users`, `wait_state`, `reaction`, `voice_*`, …). Owning the wiring
/// here keeps one live socket per signed-in user; the cubit just consumes the
/// typed streams below.
class WatchSocketDataSource {
  WatchSocketDataSource(this._socket, this._identity);

  final SocketCubit _socket;
  final IdentityCubit _identity;

  String? _slug;

  // ---- inbound streams ---------------------------------------------------
  final _sync = StreamController<PlaybackSync>.broadcast();
  final _chatHistory = StreamController<List<ChatMessage>>.broadcast();
  final _chat = StreamController<ChatMessage>.broadcast();
  final _chatThrottled = StreamController<String?>.broadcast();
  final _viewerCount = StreamController<int>.broadcast();
  final _presence = StreamController<List<PresenceUser>>.broadcast();
  final _waitState = StreamController<List<PresenceUser>>.broadcast();
  final _sourceChanged = StreamController<SourceChange>.broadcast();
  final _subtitleChanged = StreamController<String>.broadcast();
  final _subtitleSettings = StreamController<SubtitleSettings>.broadcast();
  final _forceResync = StreamController<PlaybackSync>.broadcast();
  final _reaction = StreamController<ReactionEvent>.broadcast();
  final _roomDeleted = StreamController<void>.broadcast();
  final _voice = StreamController<VoiceEvent>.broadcast();

  Stream<PlaybackSync> get sync => _sync.stream;
  Stream<List<ChatMessage>> get chatHistory => _chatHistory.stream;
  Stream<ChatMessage> get chat => _chat.stream;

  /// Emits the `clientId` of a throttled send (null when unknown), so the
  /// matching optimistic message can be flagged as failed.
  Stream<String?> get chatThrottled => _chatThrottled.stream;

  /// Socket connectivity transitions (deduped). Lets the room flush its pending
  /// chat outbox the moment the connection comes back.
  Stream<bool> get connected => _socket.stream.map((s) => s.isConnected).distinct();
  Stream<int> get viewerCount => _viewerCount.stream;
  Stream<List<PresenceUser>> get presence => _presence.stream;
  Stream<List<PresenceUser>> get waitState => _waitState.stream;
  Stream<SourceChange> get sourceChanged => _sourceChanged.stream;
  Stream<String> get subtitleChanged => _subtitleChanged.stream;
  Stream<SubtitleSettings> get subtitleSettings => _subtitleSettings.stream;
  Stream<PlaybackSync> get forceResync => _forceResync.stream;
  Stream<ReactionEvent> get reaction => _reaction.stream;
  Stream<void> get roomDeleted => _roomDeleted.stream;
  Stream<VoiceEvent> get voice => _voice.stream;

  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<dynamic>? _statusSub;

  /// Joins [slug]: ensures the socket is up, announces the display name, binds
  /// every room event, and (re)emits `join_room` on each (re)connection.
  void join(String slug) {
    _slug = slug;
    _socket.connect(url: AppConfig.socketBaseUrl);
    _bind();

    _statusSub ??= _socket.stream.listen((s) {
      if (s.isConnected) _announceAndJoin();
    });
    if (_socket.isConnected) _announceAndJoin();
  }

  void _announceAndJoin() {
    _identity.push();
    _socket.emitEvent('join_room', {'roomSlug': _slug});
  }

  void _bind() {
    if (_subs.isNotEmpty) return; // bind once; `on` is idempotent across reconnects
    _subs.addAll([
      _socket.on('sync').listen((d) => _emitSync(_sync, d)),
      _socket.on('rate_changed').listen((d) => _emitSync(_sync, d)),
      _socket.on('force_resync').listen((d) => _emitSync(_forceResync, d)),
      _socket.on('chat_history').listen(_onChatHistory),
      _socket.on('chat').listen(_onChat),
      _socket.on('chat_throttled').listen(_onChatThrottled),
      _socket.on('viewer_count').listen(_onViewerCount),
      _socket.on('room_users').listen((d) => _onUsers(_presence, d)),
      _socket.on('wait_state').listen((d) => _onUsers(_waitState, d)),
      _socket.on('source_changed').listen(_onSourceChanged),
      _socket.on('subtitle_changed').listen(_onSubtitleChanged),
      _socket.on('subtitle_settings_changed').listen(_onSubtitleSettings),
      _socket.on('reaction').listen(_onReaction),
      _socket.on('room_deleted').listen((_) => _add(_roomDeleted, null)),
      _socket.on('voice_start').listen((d) => _onVoice(VoicePhase.start, d)),
      _socket.on('voice_chunk').listen((d) => _onVoice(VoicePhase.chunk, d)),
      _socket.on('voice_end').listen((d) => _onVoice(VoicePhase.end, d)),
    ]);
  }

  // ---- outbound commands -------------------------------------------------

  void sendControl({required String action, double? currentTime, double? rate}) {
    _socket.emitEvent('control', {
      'action': action,
      'currentTime': ?currentTime,
      'rate': ?rate,
    });
  }

  void sendChat(String text, {String? clientId}) =>
      _socket.emitEvent('chat', {'text': text, 'clientId': ?clientId});

  void sendReaction(String emoji) => _socket.emitEvent('reaction', {'emoji': emoji});

  void setBuffering(bool buffering) => _socket.emitEvent('buffer_state', {'buffering': buffering});

  void requestResync() => _socket.emitEvent('force_resync');

  void changeSource(String url) => _socket.emitEvent('change_source', {'url': url});

  /// Updates the room's shared subtitle settings. Only the provided fields are
  /// sent; the server clamps, persists and rebroadcasts them to everyone.
  void setSubtitleSettings({double? offset, int? weight, int? size}) {
    _socket.emitEvent('set_subtitle_settings', {
      'offset': ?offset,
      'weight': ?weight,
      'size': ?size,
    });
  }

  void voiceStart(String mimeType) => _socket.emitEvent('voice_start', {'mimeType': mimeType});
  void voiceChunk(List<int> bytes) => _socket.emitEvent('voice_chunk', bytes);
  void voiceEnd() => _socket.emitEvent('voice_end');

  /// Leave the room without tearing down the shared socket (decrements the
  /// server-side viewer count via the additive `leave_room` handler).
  void leave() {
    if (_slug != null) _socket.emitEvent('leave_room');
    _slug = null;
  }

  // ---- inbound parsing ---------------------------------------------------

  void _emitSync(StreamController<PlaybackSync> c, dynamic d) {
    if (d is Map) _add(c, PlaybackSync.fromJson(Map<String, dynamic>.from(d)));
  }

  void _onChatHistory(dynamic d) {
    if (d is! Map) return;
    final msgs = d['messages'];
    if (msgs is! List) return;
    _add(
      _chatHistory,
      msgs
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }

  void _onChat(dynamic d) {
    if (d is Map) _add(_chat, ChatMessage.fromJson(Map<String, dynamic>.from(d)));
  }

  void _onChatThrottled(dynamic d) {
    _add(_chatThrottled, d is Map ? d['clientId']?.toString() : null);
  }

  void _onViewerCount(dynamic d) {
    if (d is Map && d['count'] is num) _add(_viewerCount, (d['count'] as num).toInt());
  }

  void _onUsers(StreamController<List<PresenceUser>> c, dynamic d) {
    if (d is Map) _add(c, PresenceUser.listFrom(d['users']));
  }

  void _onSourceChanged(dynamic d) {
    if (d is Map) _add(_sourceChanged, SourceChange.fromJson(Map<String, dynamic>.from(d)));
  }

  void _onSubtitleChanged(dynamic d) {
    if (d is Map && d['filename'] != null) _add(_subtitleChanged, d['filename'].toString());
  }

  void _onSubtitleSettings(dynamic d) {
    if (d is Map) _add(_subtitleSettings, SubtitleSettings.fromJson(Map<String, dynamic>.from(d)));
  }

  void _onReaction(dynamic d) {
    if (d is Map) _add(_reaction, ReactionEvent.fromJson(Map<String, dynamic>.from(d)));
  }

  void _onVoice(VoicePhase phase, dynamic d) {
    if (d is! Map) return;
    _add(
      _voice,
      VoiceEvent(
        phase: phase,
        id: d['id']?.toString() ?? '',
        name: d['name']?.toString(),
        mimeType: d['mimeType']?.toString(),
        chunk: phase == VoicePhase.chunk ? _bytesFrom(d['chunk']) : null,
      ),
    );
  }

  List<int>? _bytesFrom(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is ByteBuffer) return raw.asUint8List();
    if (raw is List<int>) return raw;
    if (raw is List) return raw.whereType<num>().map((n) => n.toInt()).toList();
    return null;
  }

  void _add<T>(StreamController<T> c, T value) {
    if (!c.isClosed) c.add(value);
  }

  Future<void> dispose() async {
    leave();
    await _statusSub?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _sync.close();
    await _chatHistory.close();
    await _chat.close();
    await _chatThrottled.close();
    await _viewerCount.close();
    await _presence.close();
    await _waitState.close();
    await _sourceChanged.close();
    await _subtitleChanged.close();
    await _subtitleSettings.close();
    await _forceResync.close();
    await _reaction.close();
    await _roomDeleted.close();
    await _voice.close();
  }
}

enum VoicePhase { start, chunk, end }

/// A relayed push-to-talk event from another viewer.
class VoiceEvent {
  const VoiceEvent({required this.phase, required this.id, this.name, this.mimeType, this.chunk});

  final VoicePhase phase;
  final String id;
  final String? name;
  final String? mimeType;
  final List<int>? chunk;
}
