import 'package:get_it/get_it.dart';

import '/core/network/api_client.dart';
import '../data/operations_datasource.dart';
import '../presentation/bloc/operations_cubit.dart';

/// Wires the operations (server transfers) feature: a datasource over the shared
/// [ApiClient] and the long-lived [OperationsCubit] that polls it. The cubit is
/// a singleton so the Rooms app-bar button and the create-room upload flow share
/// one live list.
Future<void> injectOperationsSingletons(GetIt sl) async {
  sl.registerLazySingleton<OperationsDataSource>(() => OperationsDataSource(sl<ApiClient>()));
  sl.registerSingleton<OperationsCubit>(OperationsCubit(sl<OperationsDataSource>()));
}
