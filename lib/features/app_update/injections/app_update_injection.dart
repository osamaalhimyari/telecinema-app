import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '/core/services/apk_installer.dart';
import '../data/datasources/app_update_remote_datasource.dart';
import '../data/repositories/app_update_repository_impl.dart';
import '../domain/repositories/app_update_repository.dart';
import '../domain/usecases/check_for_update_usecase.dart';
import '../presentation/bloc/app_update_cubit.dart';

/// Registers the in-app update feature. The cubit is an app-lifetime singleton
/// (provided at the root in `main.dart`), so the app bar button and the forced
/// gate share one source of truth.
Future<void> injectAppUpdateSingletons(GetIt sl) async {
  sl.registerLazySingleton<AppUpdateRemoteDataSource>(
    () => AppUpdateRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AppUpdateRepository>(
    () => AppUpdateRepositoryImpl(sl<AppUpdateRemoteDataSource>()),
  );
  sl.registerLazySingleton<CheckForUpdateUseCase>(
    () => CheckForUpdateUseCase(sl<AppUpdateRepository>()),
  );
  sl.registerLazySingleton<ApkInstaller>(() => const ApkInstaller());

  sl.registerLazySingleton<AppUpdateCubit>(
    () => AppUpdateCubit(
      sl<CheckForUpdateUseCase>(),
      sl<AppUpdateRepository>(),
      sl<ApkInstaller>(),
    ),
  );
}
