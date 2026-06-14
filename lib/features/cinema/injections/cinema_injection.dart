import 'package:get_it/get_it.dart';

import '../data/cinema_api.dart';
import '../data/cinema_resolver.dart';
import '../data/datasources/cinema_remote_datasource.dart';
import '../presentation/bloc/detail/cinema_detail_cubit.dart';

/// Registers the ISOLATED Cinema feature. Browsing/search hit the EgyBest API
/// over `package:http` ([CinemaApi]); link resolution runs on-device
/// ([CinemaResolver]) — both independent of the backend [ApiClient], mirroring
/// Browse/topcinema. The resolved link is handed to the existing Create Room
/// screen, so nothing in the rooms feature is modified.
Future<void> injectCinemaSingletons(GetIt sl) async {
  sl.registerLazySingleton<CinemaApi>(() => CinemaApi());
  sl.registerLazySingleton<CinemaResolver>(() => CinemaResolver());
  sl.registerLazySingleton<CinemaRemoteDataSource>(
    () => CinemaRemoteDataSourceImpl(sl<CinemaApi>(), sl<CinemaResolver>()),
  );
}

/// Page-scoped BLoCs — fresh each time a Cinema detail page opens. (The Cinema
/// grid was merged into the unified Browse tab; only the detail flow remains.)
Future<void> injectCinemaFactories(GetIt sl) async {
  sl.registerFactory<CinemaDetailCubit>(
    () => CinemaDetailCubit(sl<CinemaRemoteDataSource>()),
  );
}
