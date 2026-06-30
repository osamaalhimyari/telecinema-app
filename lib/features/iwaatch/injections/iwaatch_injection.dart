import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '../data/datasources/iwaatch_remote_datasource.dart';

/// Registers the ISOLATED iwaatch "direct link" provider. Resolution runs on the
/// backend (iwaatch is reachable from the server but geo-blocked for clients),
/// so this only needs the shared [ApiClient]. No cubit/factory — the picker
/// drives the data source, exactly like topcinema.
Future<void> injectIwaatchSingletons(GetIt sl) async {
  sl.registerLazySingleton<IwaatchRemoteDataSource>(
    () => IwaatchRemoteDataSourceImpl(sl<ApiClient>()),
  );
}
