import 'package:dio/dio.dart';

import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../../domain/entities/create_room_params.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/room_type.dart';
import '../models/room_model.dart';

/// Reads/writes the room catalogue over the JSON API (`/api/rooms…`).
/// Throws [ServerException]; the repository turns those into [Failure]s.
abstract class RoomsRemoteDataSource {
  Future<List<RoomModel>> fetchRooms();
  Future<RoomModel> fetchRoom(String slug);

  /// Returns `true` when the password matches. Throws for transport errors.
  Future<bool> unlock(String slug, String password);

  /// Returns the created room, or — for the download flow — a `jobId` to poll.
  Future<({RoomModel? room, String? jobId})> create(
    CreateRoomParams params, {
    void Function(int sent, int total)? onUploadProgress,
  });

  Future<DownloadProgress> downloadProgress(String jobId);
  Future<void> delete(String slug, {String? password});
  Future<String> uploadSubtitle(String slug, String filePath);
}

class RoomsRemoteDataSourceImpl implements RoomsRemoteDataSource {
  RoomsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<RoomModel>> fetchRooms() async {
    final res = await _client.get('/rooms');
    if (!res.success) throw ServerException(res.message ?? 'rooms_fetch_failed');
    final data = res.data;
    final list = data is Map<String, dynamic> ? data['rooms'] : data;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => RoomModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  @override
  Future<RoomModel> fetchRoom(String slug) async {
    final res = await _client.get('/rooms/$slug');
    if (!res.success) throw ServerException(res.message ?? 'room_not_found');
    final data = res.data;
    final map = (data is Map<String, dynamic> && data['room'] is Map)
        ? Map<String, dynamic>.from(data['room'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return RoomModel.fromJson(map);
  }

  @override
  Future<bool> unlock(String slug, String password) async {
    try {
      final res = await _client.post('/rooms/$slug/unlock', data: {'password': password});
      return res.success;
    } on ServerException catch (e) {
      // 403 here is a wrong password, not a transport failure.
      if (e.statusCode == 403) return false;
      rethrow;
    }
  }

  @override
  Future<({RoomModel? room, String? jobId})> create(
    CreateRoomParams params, {
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    final type = switch (params.type) {
      RoomType.external => 'external',
      RoomType.download => 'download',
      RoomType.torrent => 'torrent',
      RoomType.upload => 'upload',
    };

    if (params.type == RoomType.upload) {
      final form = FormData.fromMap({
        'name': params.name,
        'roomType': type,
        if (params.password != null && params.password!.isNotEmpty) 'password': params.password,
        if (params.category != null && params.category!.isNotEmpty) 'category': params.category,
        if (params.imdbId != null && params.imdbId!.isNotEmpty) 'imdbId': params.imdbId,
        if (params.reactions != null) 'reactions': _encodeReactions(params.reactions!),
        'video': await MultipartFile.fromFile(params.localVideoPath!),
      });
      final res = await _client.postMultipart(
        '/rooms',
        data: form,
        onSendProgress: onUploadProgress,
      );
      if (!res.success) throw ServerException(res.message ?? 'room_create_failed');
      return (room: _roomFrom(res.data), jobId: null);
    }

    final res = await _client.post('/rooms', data: {
      'name': params.name,
      'roomType': type,
      if (params.password != null && params.password!.isNotEmpty) 'password': params.password,
      if (params.externalUrl != null) 'externalUrl': params.externalUrl,
      if (params.videoUrl != null) 'videoUrl': params.videoUrl,
      if (params.magnet != null) 'magnet': params.magnet,
      if (params.category != null && params.category!.isNotEmpty) 'category': params.category,
      if (params.imdbId != null && params.imdbId!.isNotEmpty) 'imdbId': params.imdbId,
      if (params.reactions != null) 'reactions': _encodeReactions(params.reactions!),
    });
    if (!res.success) throw ServerException(res.message ?? 'room_create_failed');

    final data = res.data;
    if (data is Map<String, dynamic> && data['jobId'] != null) {
      return (room: null, jobId: data['jobId'].toString());
    }
    return (room: _roomFrom(data), jobId: null);
  }

  @override
  Future<DownloadProgress> downloadProgress(String jobId) async {
    final res = await _client.get('/rooms/download/$jobId');
    if (!res.success) throw ServerException(res.message ?? 'download_not_found');
    final m = Map<String, dynamic>.from(res.data as Map);
    return DownloadProgress(
      status: DownloadProgress.statusFromString(m['status']?.toString()),
      percent: m['percent'] is num ? (m['percent'] as num).toInt() : null,
      bytesDownloaded: m['bytesDownloaded'] is num ? (m['bytesDownloaded'] as num).toInt() : 0,
      totalBytes: m['totalBytes'] is num ? (m['totalBytes'] as num).toInt() : null,
      error: m['error']?.toString(),
      slug: m['slug']?.toString(),
    );
  }

  @override
  Future<void> delete(String slug, {String? password}) async {
    final res = await _client.delete(
      '/rooms/$slug',
      data: {'password': ?password},
    );
    if (!res.success) throw ServerException(res.message ?? 'room_delete_failed');
  }

  @override
  Future<String> uploadSubtitle(String slug, String filePath) async {
    final form = FormData.fromMap({'subtitle': await MultipartFile.fromFile(filePath)});
    final res = await _client.postMultipart('/rooms/$slug/subtitle', data: form);
    if (!res.success) throw ServerException(res.message ?? 'subtitle_upload_failed');
    final data = res.data;
    return (data is Map && data['filename'] != null) ? data['filename'].toString() : '';
  }

  RoomModel _roomFrom(dynamic data) {
    final map = (data is Map<String, dynamic> && data['room'] is Map)
        ? Map<String, dynamic>.from(data['room'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return RoomModel.fromJson(map);
  }

  String _encodeReactions(List<String> reactions) =>
      '[${reactions.map((e) => '"$e"').join(',')}]';
}
