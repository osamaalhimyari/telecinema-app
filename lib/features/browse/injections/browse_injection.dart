import 'package:get_it/get_it.dart';

import '../data/datasources/cinemeta_datasource.dart';
import '../data/datasources/torrent_datasource.dart';
import '../data/repositories/browse_repository_impl.dart';
import '../domain/repositories/browse_repository.dart';
import '../domain/usecases/find_torrents_usecase.dart';
import '../domain/usecases/get_catalog_usecase.dart';
import '../domain/usecases/get_meta_detail_usecase.dart';
import '../domain/usecases/search_catalog_usecase.dart';
import '../presentation/bloc/browse/browse_cubit.dart';
import '../presentation/bloc/detail/detail_cubit.dart';

/// Browse uses public catalogue APIs (Cinemeta + apibay) over `package:http`,
/// independent of the backend [ApiClient] — so it owns its own datasources.
Future<void> injectBrowseSingletons(GetIt sl) async {
  // Data layer
  sl.registerLazySingleton<CinemetaDataSource>(() => CinemetaDataSourceImpl());
  sl.registerLazySingleton<TorrentDataSource>(() => TorrentDataSourceImpl());
  sl.registerLazySingleton<BrowseRepository>(
    () => BrowseRepositoryImpl(sl<CinemetaDataSource>(), sl<TorrentDataSource>()),
  );

  // Use cases
  sl.registerLazySingleton<GetCatalogUseCase>(
    () => GetCatalogUseCase(sl<BrowseRepository>()),
  );
  sl.registerLazySingleton<SearchCatalogUseCase>(
    () => SearchCatalogUseCase(sl<BrowseRepository>()),
  );
  sl.registerLazySingleton<GetMetaDetailUseCase>(
    () => GetMetaDetailUseCase(sl<BrowseRepository>()),
  );
  sl.registerLazySingleton<FindTorrentsUseCase>(
    () => FindTorrentsUseCase(sl<BrowseRepository>()),
  );
}

/// Page-scoped BLoCs — fresh each time a Browse page opens.
Future<void> injectBrowseFactories(GetIt sl) async {
  sl.registerFactory<BrowseCubit>(
    () => BrowseCubit(sl<GetCatalogUseCase>(), sl<SearchCatalogUseCase>()),
  );
  sl.registerFactory<DetailCubit>(
    () => DetailCubit(sl<GetMetaDetailUseCase>(), sl<FindTorrentsUseCase>()),
  );
}
