import 'package:equatable/equatable.dart';

import '/core/config/app_config.dart';
import '/core/livetv/live_stream.dart';
import 'room_type.dart';

/// A single watch-party room. Streamable URLs are derived on the fly from the
/// stored filenames + [AppConfig.baseUrl], so the entity stays decoupled from
/// the deployment host.
class Room extends Equatable {
  const Room({
    required this.id,
    required this.name,
    required this.slug,
    required this.roomType,
    required this.hasPassword,
    required this.isUserCreated,
    required this.viewCount,
    required this.viewerCount,
    required this.reactions,
    this.externalUrl,
    this.videoFilename,
    this.thumbnailFilename,
    this.subtitleFilename,
    this.viewCountLabel,
    this.createdAgo,
    this.category,
    this.magnet,
    this.imdbId,
  });

  final int id;
  final String name;
  final String slug;
  final RoomType roomType;
  final bool hasPassword;
  final bool isUserCreated;
  final int viewCount;

  /// Live count of people currently inside the room (from the socket layer).
  final int viewerCount;

  /// The emoji palette this room offers for reactions.
  final List<String> reactions;

  final String? externalUrl;
  final String? videoFilename;
  final String? thumbnailFilename;
  final String? subtitleFilename;
  final String? viewCountLabel;
  final String? createdAgo;
  final String? category;

  /// Magnet URI for torrent rooms (exposed by the server only for this type).
  /// Used to stream the torrent on-device; null for every other room type.
  final String? magnet;

  /// IMDB id of the title this room plays (e.g. `tt1190634`), set when the room
  /// was created from the Browse catalogue. Drives the in-room "Download
  /// subtitle" search; null for manually created rooms (title search fallback).
  final String? imdbId;

  bool get isExternal => roomType.isExternal;

  bool get isTv => roomType.isTv;

  /// For a live-TV room, the unpacked source (stream URL + per-channel headers +
  /// channel path for token refresh); null for every other room type. The
  /// packed string is stored in [externalUrl].
  LiveStreamRef? get liveStream =>
      roomType.isTv ? LiveStreamCodec.unpack(externalUrl) : null;

  /// Streamable video URL: the swarm stream for torrent rooms, the server proxy
  /// for youtube/live-TV rooms, the stored file for upload/download rooms, null
  /// for external (WebView) rooms.
  String? get videoUrl {
    if (isExternal) return null;
    if (isTv) return AppConfig.liveStreamUrl(slug);
    if (roomType.isTorrent) return AppConfig.torrentStreamUrl(slug);
    if (roomType.isYoutube) return AppConfig.youtubeStreamUrl(slug);
    return AppConfig.videoUrl(videoFilename);
  }

  /// True for rooms backed by a plain file on the server (upload/download and
  /// any other file-backed type). These are the only rooms the server can
  /// transcode to adaptive HLS — torrent/youtube/external/tv are excluded
  /// because they carry no server-side file to transcode.
  bool get supportsHls =>
      !isExternal &&
      !isTv &&
      !roomType.isTorrent &&
      !roomType.isYoutube &&
      (videoFilename?.isNotEmpty ?? false);

  /// Adaptive-HLS master URL for file rooms — the "Auto" quality that lets
  /// media_kit/libmpv adapt across the server's bitrate ladder. Null for rooms
  /// that can't be served as HLS.
  String? get hlsUrl => supportsHls ? AppConfig.hlsUrl(slug) : null;

  /// A single pinned-quality HLS variant URL (server ladder index, 0 = highest
  /// quality). Null for rooms that can't be served as HLS.
  String? hlsVariantUrl(int index) =>
      supportsHls ? AppConfig.hlsVariantUrl(slug, index) : null;

  /// A stored full URL (a catalogue poster) is used as-is; a bare filename is a
  /// built-in placeholder served from the host's `/thumbnails/`.
  String? get thumbnailUrl {
    final t = thumbnailFilename;
    if (t != null && (t.startsWith('http://') || t.startsWith('https://'))) {
      return t;
    }
    return AppConfig.thumbnailUrl(t);
  }

  String? get subtitleUrl => AppConfig.subtitleUrl(subtitleFilename);

  Room copyWith({int? viewerCount, String? externalUrl, String? subtitleFilename}) => Room(
    id: id,
    name: name,
    slug: slug,
    roomType: roomType,
    hasPassword: hasPassword,
    isUserCreated: isUserCreated,
    viewCount: viewCount,
    viewerCount: viewerCount ?? this.viewerCount,
    reactions: reactions,
    externalUrl: externalUrl ?? this.externalUrl,
    videoFilename: videoFilename,
    thumbnailFilename: thumbnailFilename,
    subtitleFilename: subtitleFilename ?? this.subtitleFilename,
    viewCountLabel: viewCountLabel,
    createdAgo: createdAgo,
    category: category,
    magnet: magnet,
    imdbId: imdbId,
  );

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    roomType,
    hasPassword,
    viewerCount,
    externalUrl,
    subtitleFilename,
    reactions,
  ];
}
