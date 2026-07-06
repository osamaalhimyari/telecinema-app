import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '/core/constants/app_constants.dart';
import '/core/localization/app_localizations.dart';
import '/core/localization/translation_keys.dart';
import '/core/services/locale_service.dart';

/// A snapshot of one subsystem's in-flight work, reported to the controller.
///
/// [CacheManager] (on-device downloads) and [OperationsCubit] (room-creation
/// uploads / server downloads) each report their own snapshot; the controller
/// merges them to decide whether the foreground service runs and what its
/// notification says.
class ForegroundJobs {
  const ForegroundJobs({this.count = 0, this.label, this.percent});

  /// Number of currently-active jobs in this source.
  final int count;

  /// A representative title to show (e.g. the room / video name); null hides it.
  final String? label;

  /// 0–100 for the representative job, or null when indeterminate.
  final int? percent;

  static const none = ForegroundJobs();
}

/// Owns the Android foreground service that keeps the process alive — with an
/// ongoing progress notification — while any transfer is running: a room being
/// created (upload / server-side download) or a video being pulled into the
/// on-device cache. Without it, Android is free to kill the backgrounded app
/// mid-transfer, stalling the download until the user reopens the app.
///
/// The download/upload code itself runs in the main isolate; this service only
/// keeps that isolate alive when the app is backgrounded (it does **not** spawn
/// a background task handler). The service starts when the first job appears,
/// updates its notification as progress changes, and stops once everything is
/// idle. A no-op on every non-Android platform (foreground services are an
/// Android concept — web/desktop/iOS keep working while the app is open).
class ForegroundServiceController {
  ForegroundServiceController(this._localeService);

  final LocaleService _localeService;

  /// Fixed notification/service id for this app's single transfer service.
  static const int _serviceId = 41207;

  /// Latest reported snapshot per source key (`'cache'`, `'operations'`).
  final Map<String, ForegroundJobs> _sources = {};

  /// Live subscriptions from [bindSource], cancelled on [dispose].
  final List<StreamSubscription<ForegroundJobs>> _bindings = [];

  bool _initialized = false;
  bool _permissionRequested = false;

  /// Serializes every start/update/stop so the plugin's internal
  /// `isRunningService` checks (and its 5s start deadline) never race a rapid
  /// start→stop→start sequence.
  Future<void> _queue = Future<void>.value();

  /// Debounces notification updates — cache progress fires roughly every 2 MB,
  /// which would otherwise hammer the platform channel.
  Timer? _debounce;

  String? _lastTitle;
  String? _lastText;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Records [source]'s current work. A count of 0 clears the source. Safe to
  /// call as often as progress updates arrive — updates are debounced.
  void report(String source, ForegroundJobs jobs) {
    if (!_supported) return;
    if (jobs.count <= 0) {
      _sources.remove(source);
    } else {
      _sources[source] = jobs;
    }
    _scheduleApply();
  }

  /// Seeds [source] with [initial] and keeps it in sync with [stream]. Each
  /// caller maps its own domain state to a [ForegroundJobs] snapshot, so this
  /// controller stays feature-agnostic. The subscription lives for the app.
  void bindSource(
    String source,
    ForegroundJobs initial,
    Stream<ForegroundJobs> stream,
  ) {
    report(source, initial);
    _bindings.add(stream.listen((j) => report(source, j)));
  }

  void _scheduleApply() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _apply);
  }

  void _apply() {
    final total = _sources.values.fold<int>(0, (sum, j) => sum + j.count);
    final shouldRun = total > 0;
    final (title, text) = _composeNotification(total);
    // Chain onto the queue so service calls can't overlap; swallow errors so one
    // failed reconcile never poisons the chain for the next report.
    _queue = _queue
        .then((_) => _reconcile(shouldRun, title, text))
        .catchError((_) {});
  }

  Future<void> _reconcile(bool shouldRun, String title, String text) async {
    await _ensureInitialized();

    final running = await FlutterForegroundTask.isRunningService;
    if (shouldRun) {
      if (!running) {
        await _ensurePermission();
        await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
        );
      } else if (title != _lastTitle || text != _lastText) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
      _lastTitle = title;
      _lastText = text;
    } else {
      if (running) await FlutterForegroundTask.stopService();
      _lastTitle = null;
      _lastText = null;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'telecinema_transfers',
        channelName: _tr(TranslationKeys.fgChannelName),
        channelDescription: _tr(TranslationKeys.fgChannelDesc),
        // LOW keeps the notification silent and unobtrusive (no sound / heads-up)
        // — it's a passive progress indicator, not an alert.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No periodic background callback — the transfer runs in the main
        // isolate; the service only needs to keep the process alive.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        // A transfer can't survive the process being killed (its Dio stream and
        // cubit live in the main isolate), so don't auto-restart into a headless
        // service that can't drive it — the cache download resumes on next open.
        allowAutoRestart: false,
        // Same reason: when the user swipes the app away, the isolate driving the
        // transfer dies, so stop the service too instead of stranding a notification.
        stopWithTask: true,
      ),
    );
    _initialized = true;
  }

  /// Requests the Android 13+ notification permission once, contextually (the
  /// app is in the foreground when the first transfer starts). The service still
  /// keeps the process alive if denied — only the notification is hidden.
  Future<void> _ensurePermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      /* permission APIs unavailable on this OS version — ignore */
    }
  }

  (String, String) _composeNotification(int total) {
    final title = AppConstants.appName;
    if (total <= 0) return (title, '');

    // Prefer a source that carries a concrete label to show.
    ForegroundJobs? primary;
    for (final j in _sources.values) {
      if ((j.label?.trim().isNotEmpty ?? false)) {
        primary = j;
        break;
      }
    }

    if (total == 1 && primary != null) {
      final pct = primary.percent;
      final text = pct != null ? '${primary.label} • $pct%' : primary.label!;
      return (title, text);
    }

    // Several transfers in flight → a count summary ("3 active downloads").
    return (title, '$total ${_tr(TranslationKeys.fgActiveTransfers)}');
  }

  String _tr(String key) => AppLocalizations(_localeService.locale).tr(key);

  /// Stops the service and drops all tracked sources. Called on app teardown.
  Future<void> dispose() async {
    _debounce?.cancel();
    for (final b in _bindings) {
      await b.cancel();
    }
    _bindings.clear();
    _sources.clear();
    if (!_supported) return;
    _queue = _queue.then((_) async {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    }).catchError((_) {});
    await _queue;
  }
}
