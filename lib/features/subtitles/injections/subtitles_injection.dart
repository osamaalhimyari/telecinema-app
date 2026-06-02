import 'package:get_it/get_it.dart';

import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
import '../data/datasources/opensubtitles_datasource.dart';
import '../data/repositories/subtitles_repository_impl.dart';
import '../domain/repositories/subtitles_repository.dart';
import '../domain/usecases/download_subtitle_usecase.dart';
import '../domain/usecases/search_subtitles_usecase.dart';
import '../presentation/bloc/subtitles_cubit.dart';

/// Subtitles use the public OpenSubtitles REST API over `package:http`,
/// independent of the backend [ApiClient] — same shape as the Browse feature.
/// The apply step reuses the rooms feature's [UploadSubtitleUseCase].
Future<void> injectSubtitlesSingletons(GetIt sl) async {
  sl.registerLazySingleton<OpenSubtitlesDataSource>(() => OpenSubtitlesDataSourceImpl());
  sl.registerLazySingleton<SubtitlesRepository>(
    () => SubtitlesRepositoryImpl(sl<OpenSubtitlesDataSource>()),
  );

  sl.registerLazySingleton<SearchSubtitlesUseCase>(
    () => SearchSubtitlesUseCase(sl<SubtitlesRepository>()),
  );
  sl.registerLazySingleton<DownloadSubtitleUseCase>(
    () => DownloadSubtitleUseCase(sl<SubtitlesRepository>()),
  );
}

/// Page-scoped cubit — fresh each time the Download-subtitle page opens.
Future<void> injectSubtitlesFactories(GetIt sl) async {
  sl.registerFactory<SubtitlesCubit>(
    () => SubtitlesCubit(
      sl<SearchSubtitlesUseCase>(),
      sl<DownloadSubtitleUseCase>(),
      sl<UploadSubtitleUseCase>(),
    ),
  );
}
