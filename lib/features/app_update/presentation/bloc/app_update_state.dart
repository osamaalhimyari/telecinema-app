import 'package:equatable/equatable.dart';

import '../../domain/entities/app_update_info.dart';

/// Lifecycle of the in-app updater:
///  idle → checking → (upToDate | available)
///  available → downloading → readyToInstall → installing
enum UpdateStatus { idle, checking, upToDate, available, downloading, readyToInstall, installing, error }

class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.info = AppUpdateInfo.none,
    this.received = 0,
    this.total = 0,
    this.apkPath,
    this.errorKey,
  });

  final UpdateStatus status;
  final AppUpdateInfo info;
  final int received;
  final int total;
  final String? apkPath;

  /// Translation key for the last error, if any.
  final String? errorKey;

  /// A newer build exists (whether or not the user has acted on it).
  bool get hasUpdate => info.updateAvailable;

  /// The user must update before continuing — drives the blocking gate.
  bool get isForced => info.forced && info.updateAvailable;

  bool get isDownloading => status == UpdateStatus.downloading;
  bool get isReady => status == UpdateStatus.readyToInstall || status == UpdateStatus.installing;

  /// 0..1 download progress, or null when the total size is still unknown
  /// (shows an indeterminate spinner).
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  int? get percent => total > 0 ? ((received / total) * 100).round() : null;

  AppUpdateState copyWith({
    UpdateStatus? status,
    AppUpdateInfo? info,
    int? received,
    int? total,
    String? apkPath,
    String? errorKey,
    bool clearError = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      info: info ?? this.info,
      received: received ?? this.received,
      total: total ?? this.total,
      apkPath: apkPath ?? this.apkPath,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [status, info, received, total, apkPath, errorKey];
}
