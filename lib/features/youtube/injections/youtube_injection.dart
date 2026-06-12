import 'package:get_it/get_it.dart';

import '../data/datasources/youtube_remote_datasource.dart';
import '../data/youtube_client.dart';

/// Registers the ISOLATED YouTube feature. Search + quality enumeration run
/// entirely on-device via [YoutubeClient]; the picked link + height are handed
/// to the existing Create Room screen. No cubit/factory — the page drives the
/// data source directly, mirroring the topcinema module.
Future<void> injectYoutubeSingletons(GetIt sl) async {
  sl.registerLazySingleton<YoutubeClient>(() => YoutubeClient());
  sl.registerLazySingleton<YoutubeRemoteDataSource>(
    () => YoutubeRemoteDataSourceImpl(sl<YoutubeClient>()),
  );
}
