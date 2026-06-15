import 'room.dart';
import 'room_type.dart';

/// Inputs for creating a room. Exactly one source field is required, matching
/// the chosen [type]:
///   * [RoomType.external] → [externalUrl]
///   * [RoomType.download] → [videoUrl]
///   * [RoomType.torrent]  → [magnet]
///   * [RoomType.upload]   → [localVideoPath]
class CreateRoomParams {
  const CreateRoomParams({
    required this.name,
    required this.type,
    this.password,
    this.externalUrl,
    this.videoUrl,
    this.magnet,
    this.localVideoPath,
    this.reactions,
    this.category,
    this.imdbId,
    this.maxHeight,
    this.thumbnail,
  });

  final String name;
  final RoomType type;
  final String? password;
  final String? externalUrl;
  final String? videoUrl;
  final String? magnet;
  final String? localVideoPath;
  final List<String>? reactions;
  final String? category;

  /// Poster image URL of the movie/series this room plays, carried from the
  /// catalogue. Stored as the room's thumbnail; when null the server assigns a
  /// random built-in placeholder instead.
  final String? thumbnail;

  /// IMDB id of the source title (e.g. `tt1190634`) when the room is created
  /// from the Browse catalogue; null otherwise. Persisted so the room can later
  /// search OpenSubtitles by IMDB id.
  final String? imdbId;

  /// Max video height for a server-side YouTube download (e.g. 1080), set only
  /// by the YouTube flow. Ignored by the server for non-YouTube sources.
  final int? maxHeight;
}

/// The outcome of a create call: either the room is ready immediately
/// ([room]), or a background download started and the client must poll
/// ([jobId]).
class CreateRoomResult {
  const CreateRoomResult({this.room, this.jobId});

  final Room? room;
  final String? jobId;

  bool get isPending => jobId != null;
}
