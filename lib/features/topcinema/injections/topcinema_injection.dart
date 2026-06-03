import 'package:get_it/get_it.dart';

import '../data/datasources/topcinema_remote_datasource.dart';
import '../data/topcinema_scraper.dart';

/// Registers the ISOLATED topcinema "second way". Scraping runs entirely
/// on-device via [TopcinemaScraper]; the resolved link is handed to the existing
/// Create Room screen. No cubit/factory — the picker drives the data source.
Future<void> injectTopcinemaSingletons(GetIt sl) async {
  sl.registerLazySingleton<TopcinemaScraper>(() => TopcinemaScraper());
  sl.registerLazySingleton<TopcinemaRemoteDataSource>(
    () => TopcinemaRemoteDataSourceImpl(sl<TopcinemaScraper>()),
  );
}
