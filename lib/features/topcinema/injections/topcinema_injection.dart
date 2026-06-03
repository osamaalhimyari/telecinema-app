import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '../data/datasources/topcinema_remote_datasource.dart';

/// Registers the ISOLATED topcinema "second way" data source. No cubit/factory
/// — the picker drives the data source directly and navigates to the room, so
/// nothing else in the app depends on this feature.
Future<void> injectTopcinemaSingletons(GetIt sl) async {
  sl.registerLazySingleton<TopcinemaRemoteDataSource>(
    () => TopcinemaRemoteDataSourceImpl(sl<ApiClient>()),
  );
}
