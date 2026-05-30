import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/core/config/app_config.dart';
import '/core/network/api_client.dart';
import '/core/network/dio_api_client.dart';
import '/core/services/locale_service.dart';
import '/core/services/theme_service.dart';
import '/features/browse/injections/browse_injection.dart';
import '/features/rooms/injections/rooms_injection.dart';
import '/features/watch/injections/watch_injection.dart';
import '/logic/favorites/favorites_cubit.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/localization/locale_cubit.dart';
import '/logic/socket/socket_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';
import '/logic/theme/theme_cubit.dart';

/// Long-lived singletons. Order matters: storage and the socket come up before
/// [IdentityCubit] (which needs both), and feature singletons register their
/// data layers on top of the shared [ApiClient] / [SocketCubit].
Future<void> injectSingletons(GetIt sl) async {
  // ===== Locale + theme (HydratedCubits; storage is set up in main) =====
  final localeCubit = LocaleCubit();
  sl.registerSingleton<LocaleCubit>(localeCubit);
  sl.registerSingleton<LocaleService>(localeCubit);

  final themeCubit = ThemeCubit();
  sl.registerSingleton<ThemeCubit>(themeCubit);
  sl.registerSingleton<ThemeService>(themeCubit);

  // ===== Realtime socket — generic Socket.IO client, shared by all features.
  sl.registerSingleton<SocketCubit>(SocketCubit());

  // ===== Storage =====
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<KeyValueStorage>(() => SharedPrefsStorage(prefs));

  // Apply a user-overridden server URL (set in Settings) before the network
  // layer is built, so REST, Socket.IO and media URLs all target it from launch.
  final savedUrl = prefs.getString(StorageKeys.serverBaseUrl);
  if (savedUrl != null && AppConfig.isValidUrl(savedUrl)) {
    AppConfig.baseUrl = AppConfig.normalizeUrl(savedUrl);
  }

  // ===== Network =====
  sl.registerLazySingleton<ApiClient>(() => DioApiClient());

  // ===== Identity (display name → set_name) =====
  sl.registerSingleton<IdentityCubit>(IdentityCubit(sl<KeyValueStorage>(), sl<SocketCubit>()));

  // ===== Favorites + recently-watched (local, slug-keyed) =====
  sl.registerSingleton<FavoritesCubit>(FavoritesCubit(sl<KeyValueStorage>()));

  // ===== Feature singletons =====
  await injectRoomsSingletons(sl);
  await injectWatchSingletons(sl);
  await injectBrowseSingletons(sl);
}
