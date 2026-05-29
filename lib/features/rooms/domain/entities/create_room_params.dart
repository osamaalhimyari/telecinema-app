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
