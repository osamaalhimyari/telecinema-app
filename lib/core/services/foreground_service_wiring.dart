import 'package:get_it/get_it.dart';

import '/core/services/foreground_service_controller.dart';
import '/core/services/locale_service.dart';
import '/features/cache/data/cache_manager.dart';
import '/features/cache/domain/entities/cached_video.dart';
import '/features/operations/presentation/bloc/operations_cubit.dart';
import '/features/operations/presentation/bloc/operations_state.dart';

/// Registers the [ForegroundServiceController] and binds it to the two things
/// worth keeping the app alive for while backgrounded:
///
/// * **On-device cache downloads** — [CacheManager]'s active (downloading /
///   queued) entries.
/// * **Room-creation transfers** — [OperationsCubit]'s active server downloads
///   and in-app uploads.
///
/// Both are mapped to a plain [ForegroundJobs] snapshot here so the controller
/// itself carries no feature dependencies. Must run after both singletons are
/// registered (see [injectSingletons]). A no-op off Android.
void wireForegroundService(GetIt sl) {
  final controller = ForegroundServiceController(sl<LocaleService>());
  sl.registerSingleton<ForegroundServiceController>(controller);

  final cache = sl<CacheManager>();
  controller.bindSource(
    'cache',
    _cacheJobs(cache.list()),
    cache.changes.map(_cacheJobs),
  );

  final operations = sl<OperationsCubit>();
  controller.bindSource(
    'operations',
    _operationsJobs(operations.state),
    operations.stream.map(_operationsJobs),
  );
}

/// Active on-device downloads → a notification snapshot. `queued` counts too, so
/// the service doesn't flicker off in the gap before a queued item starts.
ForegroundJobs _cacheJobs(List<CachedVideo> videos) {
  final active = videos
      .where((v) =>
          v.status == CacheStatus.downloading ||
          v.status == CacheStatus.queued)
      .toList();
  if (active.isEmpty) return ForegroundJobs.none;
  final first = active.first;
  final progress = first.progress;
  return ForegroundJobs(
    count: active.length,
    label: first.title,
    percent: progress == null ? null : (progress * 100).round(),
  );
}

/// Active server transfers / uploads → a notification snapshot.
ForegroundJobs _operationsJobs(OperationsState state) {
  final active = state.operations.where((o) => o.isActive).toList();
  if (active.isEmpty) return ForegroundJobs.none;
  final first = active.first;
  return ForegroundJobs(
    count: active.length,
    label: first.name.isNotEmpty ? first.name : null,
    percent: first.percent,
  );
}
