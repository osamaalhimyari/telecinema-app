import 'dart:convert';

import '../../domain/entities/room.dart';
import '../../domain/entities/room_type.dart';

/// Parses the JSON shape produced by `RoomsApiController.serialize` — the
/// Lucid `room.serialize()` output (camelCase columns + computed getters) plus
/// a live `viewerCount`.
class RoomModel {
  const RoomModel(this.room);

  final Room room;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      Room(
        id: _int(json['id']),
        name: (json['name'] ?? '').toString(),
        slug: (json['slug'] ?? '').toString(),
        roomType: RoomType.fromString(json['roomType']?.toString()),
        hasPassword: json['hasPassword'] == true,
        isUserCreated:
            json['isUserCreated'] == true || json['isUserCreated'] == 1,
        viewCount: _int(json['viewCount']),
        viewerCount: _int(json['viewerCount']),
        reactions: _reactions(json),
        externalUrl: _nullableString(json['externalUrl']),
        videoFilename: _nullableString(json['videoFilename']),
        thumbnailFilename: _nullableString(json['thumbnailFilename']),
        subtitleFilename: _nullableString(json['subtitleFilename']),
        viewCountLabel: _nullableString(json['viewCountLabel']),
        createdAgo: _nullableString(json['createdAgo']),
        category: _nullableString(json['category']),
        magnet: _nullableString(json['magnetUri']),
        imdbId: _nullableString(json['imdbId']),
      ),
    );
  }

  Room toEntity() => room;

  // ---- parse helpers -----------------------------------------------------

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// The server exposes the palette as the computed `reactionsList` array, but
  /// we tolerate the raw `reactions` JSON string too. Falls back to a sensible
  /// default set (matching the backend default).
  static List<String> _reactions(Map<String, dynamic> json) {
    final list = json['reactionsList'];
    if (list is List) {
      final parsed = list.whereType<String>().toList();
      if (parsed.isNotEmpty) return parsed;
    }
    final raw = json['reactions'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded.whereType<String>().toList();
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {
        /* fall through to default */
      }
    }
    return const ['👍', '❤️', '😂', '😮', '😢', '😑'];
  }
}
