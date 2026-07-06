import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '/features/cache/data/cache_manager.dart';
import '/features/operations/presentation/bloc/operations_cubit.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/socket/socket_cubit.dart';
import '../data/datasources/home_socket_datasource.dart';
import '../data/datasources/rooms_remote_datasource.dart';
import '../data/repositories/rooms_repository_impl.dart';
import '../domain/repositories/rooms_repository.dart';
import '../domain/usecases/create_room_usecase.dart';
import '../domain/usecases/delete_room_usecase.dart';
import '../domain/usecases/download_progress_usecase.dart';
import '../domain/usecases/get_room_usecase.dart';
import '../domain/usecases/get_rooms_usecase.dart';
import '../domain/usecases/unlock_room_usecase.dart';
import '../domain/usecases/upload_subtitle_usecase.dart';
import '../domain/usecases/upload_voice_usecase.dart';
import '../presentation/bloc/create_room/create_room_cubit.dart';
import '../presentation/bloc/rooms_list/rooms_list_cubit.dart';

Future<void> injectRoomsSingletons(GetIt sl) async {
  // Data layer
  sl.registerLazySingleton<RoomsRemoteDataSource>(
    () => RoomsRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<RoomsRepository>(
    () => RoomsRepositoryImpl(sl<RoomsRemoteDataSource>()),
  );
  sl.registerLazySingleton<HomeSocketDataSource>(
    () => HomeSocketDataSource(sl<SocketCubit>(), sl<IdentityCubit>()),
  );

  // Use cases
  sl.registerLazySingleton<GetRoomsUseCase>(() => GetRoomsUseCase(sl<RoomsRepository>()));
  sl.registerLazySingleton<GetRoomUseCase>(() => GetRoomUseCase(sl<RoomsRepository>()));
  sl.registerLazySingleton<UnlockRoomUseCase>(() => UnlockRoomUseCase(sl<RoomsRepository>()));
  sl.registerLazySingleton<DownloadProgressUseCase>(
    () => DownloadProgressUseCase(sl<RoomsRepository>()),
  );
  sl.registerLazySingleton<DeleteRoomUseCase>(() => DeleteRoomUseCase(sl<RoomsRepository>()));
  sl.registerLazySingleton<UploadSubtitleUseCase>(
    () => UploadSubtitleUseCase(sl<RoomsRepository>()),
  );
  sl.registerLazySingleton<UploadVoiceUseCase>(
    () => UploadVoiceUseCase(sl<RoomsRepository>()),
  );
  // Factory — carries a mutable upload-progress callback per CreateRoomCubit.
  sl.registerFactory<CreateRoomUseCase>(() => CreateRoomUseCase(sl<RoomsRepository>()));
}

/// Page-scoped BLoCs — fresh each time the page opens.
Future<void> injectRoomsFactories(GetIt sl) async {
  sl.registerFactory<RoomsListCubit>(
    () => RoomsListCubit(sl<GetRoomsUseCase>(), sl<HomeSocketDataSource>()),
  );
  sl.registerFactory<CreateRoomCubit>(
    () => CreateRoomCubit(
      sl<CreateRoomUseCase>(),
      sl<DownloadProgressUseCase>(),
      sl<OperationsCubit>(),
      sl<CacheManager>(),
    ),
  );
}
