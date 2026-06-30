import 'package:get_it/get_it.dart';

import '/core/livetv/live_stream_resolver.dart';
import '/core/network/api_client.dart';
import '/features/rooms/domain/usecases/create_room_usecase.dart';
import '../data/tv_api.dart';
import '../data/tv_live_stream_resolver.dart';
import '../presentation/bloc/tv_groups/tv_groups_cubit.dart';
import '../presentation/bloc/tv_launch/tv_launch_cubit.dart';

/// Registers the live-TV feature. The catalogue is fetched from the app's own
/// server ([TvApi] over the shared [ApiClient]) — the device never calls the
/// YacineTV provider directly. Tapping a channel previews it (single user) and
/// can then create a synced `tv` room via the existing rooms layer;
/// [TvLiveStreamResolver] (bound to the core [LiveStreamResolver] the watch
/// feature depends on) refreshes an expired stream token in place so the room
/// keeps working.
Future<void> injectTvSingletons(GetIt sl) async {
  sl.registerLazySingleton<TvApi>(() => TvApi(sl<ApiClient>()));
  sl.registerLazySingleton<LiveStreamResolver>(
    () => TvLiveStreamResolver(sl<TvApi>(), sl<ApiClient>()),
  );
}

/// Page-scoped BLoCs — a fresh instance each time the TV tab / a channel list
/// opens.
Future<void> injectTvFactories(GetIt sl) async {
  sl.registerFactory<TvGroupsCubit>(() => TvGroupsCubit(sl<TvApi>()));
  sl.registerFactory<TvLaunchCubit>(() => TvLaunchCubit(sl<CreateRoomUseCase>()));
}
