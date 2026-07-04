import 'package:get_it/get_it.dart';

import '../data/imdb_ratings_datasource.dart';

/// Registers the ISOLATED IMDb ratings source (on-device GraphQL). The detail
/// page's ratings dashboard pulls [ImdbRatingsDataSource] from here. No cubit —
/// the section widget creates a sheet-scoped one around this data source.
Future<void> injectImdbSingletons(GetIt sl) async {
  sl.registerLazySingleton<ImdbRatingsDataSource>(() => ImdbRatingsDataSourceImpl());
}
