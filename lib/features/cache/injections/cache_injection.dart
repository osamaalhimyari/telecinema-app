import 'package:get_it/get_it.dart';

import '../data/cache_manager.dart';

/// Registers the process-wide [CacheManager] and loads its on-disk index up
/// front, so the in-room download button and the Cached Videos screen have a
/// ready view of what is already cached the moment they open.
Future<void> injectCacheSingletons(GetIt sl) async {
  final manager = CacheManager();
  await manager.init();
  sl.registerSingleton<CacheManager>(manager);
}
