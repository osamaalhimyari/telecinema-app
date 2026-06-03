import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '../data/datasources/favorites_remote_datasource.dart';
import '../presentation/bloc/catalog_favorites_cubit.dart';

/// Server-backed catalogue favorites. The cubit is a singleton (not a factory)
/// because the Browse poster hearts and the Favorites tab must share one state,
/// and it's provided app-wide in `main.dart`.
Future<void> injectFavoritesSingletons(GetIt sl) async {
  sl.registerLazySingleton<FavoritesRemoteDataSource>(
    () => FavoritesRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerSingleton<CatalogFavoritesCubit>(
    CatalogFavoritesCubit(sl<FavoritesRemoteDataSource>()),
  );
}
