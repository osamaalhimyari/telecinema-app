import 'package:get_it/get_it.dart';

import '/core/services/locale_service.dart';
import '/features/browse/domain/usecases/get_catalog_usecase.dart';
import '/features/browse/domain/usecases/get_meta_detail_usecase.dart';
import '/features/browse/domain/usecases/search_catalog_usecase.dart';
import '/features/cinema/data/datasources/cinema_remote_datasource.dart';
import '../presentation/bloc/discover_cubit.dart';

/// The unified Browse tab composes Browse (Cinemeta) + Cinema (EgyBest), so it
/// reuses both feature's already-registered singletons. Page-scoped cubit.
Future<void> injectDiscoverFactories(GetIt sl) async {
  sl.registerFactory<DiscoverCubit>(
    () => DiscoverCubit(
      sl<GetCatalogUseCase>(),
      sl<SearchCatalogUseCase>(),
      sl<GetMetaDetailUseCase>(),
      sl<CinemaRemoteDataSource>(),
      sl<LocaleService>(),
    ),
  );
}
