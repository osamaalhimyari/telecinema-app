import '../../domain/entities/youtube_quality.dart';
import '../../domain/entities/youtube_video.dart';
import '../youtube_client.dart';

/// The ISOLATED YouTube "search → server-download" data source. Discovery and
/// quality enumeration run ON-DEVICE via [YoutubeClient]; the picked watch URL
/// and chosen height are then handed to the existing Create Room screen, so this
/// feature never touches the rooms feature's code — only its UI route.
abstract class YoutubeRemoteDataSource {
  /// Searches YouTube for [query].
  Future<List<YoutubeVideo>> search(String query);

  /// Available download qualities for a video id, highest first.
  Future<List<YoutubeQuality>> qualities(String videoId);
}

class YoutubeRemoteDataSourceImpl implements YoutubeRemoteDataSource {
  YoutubeRemoteDataSourceImpl(this._client);

  final YoutubeClient _client;

  @override
  Future<List<YoutubeVideo>> search(String query) => _client.search(query);

  @override
  Future<List<YoutubeQuality>> qualities(String videoId) => _client.qualities(videoId);
}
