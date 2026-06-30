import 'package:get_it/get_it.dart';

import '/features/rooms/domain/usecases/delete_room_usecase.dart';
import '/features/rooms/domain/usecases/get_room_usecase.dart';
import '/features/rooms/domain/usecases/unlock_room_usecase.dart';
import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
import '/logic/favorites/favorites_cubit.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/socket/socket_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '../data/datasources/torrent_engine.dart';
import '../data/datasources/watch_socket_datasource.dart';
import '../data/repositories/watch_repository_impl.dart';
import '../domain/repositories/watch_repository.dart';
import '../presentation/bloc/voice/voice_cubit.dart';
import '../presentation/bloc/watch_cubit.dart';

/// The socket datasource + repository are singletons — there is only one room
/// open at a time and one shared connection, so re-using the same instance
/// across rooms keeps a single set of stream controllers alive. Both
/// [WatchCubit] and [VoiceCubit] are page-scoped factories that share it.
Future<void> injectWatchSingletons(GetIt sl) async {
  sl.registerLazySingleton<WatchSocketDataSource>(
    () => WatchSocketDataSource(sl<SocketCubit>(), sl<IdentityCubit>()),
  );
  sl.registerLazySingleton<WatchRepository>(
    () => WatchRepositoryImpl(sl<WatchSocketDataSource>()),
  );
  // Process-wide embedded torrent engine (librqbit). One instance for the app:
  // the Rust engine is a global, started lazily on the first torrent room.
  sl.registerLazySingleton<TorrentEngine>(() => TorrentEngine());
}

Future<void> injectWatchFactories(GetIt sl) async {
  sl.registerFactory<WatchCubit>(
    () => WatchCubit(
      sl<WatchRepository>(),
      sl<GetRoomUseCase>(),
      sl<UnlockRoomUseCase>(),
      sl<DeleteRoomUseCase>(),
      sl<UploadSubtitleUseCase>(),
      sl<KeyValueStorage>(),
      sl<TorrentEngine>(),
      sl<FavoritesCubit>(),
      sl<IdentityCubit>(),
    ),
  );
  sl.registerFactory<VoiceCubit>(() => VoiceCubit(sl<WatchRepository>(), sl<IdentityCubit>()));
}
