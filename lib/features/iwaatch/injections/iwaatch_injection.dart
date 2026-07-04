import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '../data/datasources/iwaatch_remote_datasource.dart';

/// Registers the ISOLATED iwaatch "direct link" source. Resolution runs on the
/// backend (`GET /api/iwaatch/resolve`) because iwaatch.com is reachable from
/// the server but geo/DNS-blocked for clients — the mirror image of topcinema.
/// No cubit/factory — the picker drives the data source directly.
Future<void> injectIwaatchSingletons(GetIt sl) async {
  sl.registerLazySingleton<IwaatchRemoteDataSource>(
    () => IwaatchRemoteDataSourceImpl(sl<ApiClient>()),
  );
}
