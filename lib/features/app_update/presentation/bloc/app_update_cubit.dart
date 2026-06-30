import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/app_info.dart';
import '/core/config/app_config.dart';
import '/core/localization/translation_keys.dart';
import '/core/services/apk_installer.dart';
import '/logic/socket/socket_cubit.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../../domain/usecases/check_for_update_usecase.dart';
import 'app_update_state.dart';

/// Drives the in-app update flow: ask the server on launch, download the APK in
/// the background (the app stays usable, progress shown in the app bar), then
/// hand off to the Android installer. A forced update is surfaced by
/// [AppUpdateState.isForced]; the blocking UI lives in `UpdateGate`.
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit(this._check, this._repository, this._installer, this._socket)
    : super(const AppUpdateState()) {
    // The server broadcasts this the moment an admin publishes a new build, so
    // re-run the normal check and the update button/gate appears at once — no
    // need to wait for the next launch. Safe to subscribe before the socket
    // connects: `on` re-binds the listener once the connection comes up.
    _pushSub = _socket.on('app_version_published').listen((_) => check());
  }

  final CheckForUpdateUseCase _check;
  final AppUpdateRepository _repository;
  final ApkInstaller _installer;
  final SocketCubit _socket;

  StreamSubscription<dynamic>? _pushSub;
  CancelToken? _cancelToken;

  /// Current install's Android versionCode (build number).
  int get _currentVersionCode => int.tryParse(AppInfo.buildNumber) ?? 0;

  /// Asks the server whether a newer build exists. Safe to call on launch and
  /// on demand; ignored while a download is in flight.
  Future<void> check() async {
    if (state.isDownloading) return;
    emit(state.copyWith(status: UpdateStatus.checking, clearError: true));

    final result = await _check((versionCode: _currentVersionCode, versionName: AppInfo.version));
    result.fold(
      (failure) => emit(state.copyWith(status: UpdateStatus.error, errorKey: failure.message)),
      (info) => emit(
        state.copyWith(
          status: info.updateAvailable ? UpdateStatus.available : UpdateStatus.upToDate,
          info: info,
        ),
      ),
    );
  }

  /// What the "Update" button / forced gate calls. Installs immediately if the
  /// APK is already downloaded, otherwise downloads first.
  Future<void> start() {
    return state.isReady ? install() : download();
  }

  /// Downloads the latest APK, streaming progress into the state. Does not block
  /// the UI — the user keeps using the app while it runs.
  Future<void> download() async {
    final info = state.info;
    final path = info.downloadPath;
    if (!info.updateAvailable || path == null || state.isDownloading) return;

    _cancelToken = CancelToken();
    emit(
      state.copyWith(
        status: UpdateStatus.downloading,
        received: 0,
        total: info.fileSize ?? 0,
        clearError: true,
      ),
    );

    final url = '${AppConfig.baseUrl}$path';
    final result = await _repository.downloadApk(
      url,
      info.versionCode ?? 0,
      onProgress: (received, total) =>
          emit(state.copyWith(received: received, total: total > 0 ? total : state.total)),
      cancelToken: _cancelToken,
    );

    result.fold(
      (failure) {
        // A user-cancelled download just returns to the "available" state.
        if (failure.message == TranslationKeys.operationCanceled) {
          emit(state.copyWith(status: UpdateStatus.available, received: 0, total: 0));
        } else {
          emit(state.copyWith(status: UpdateStatus.error, errorKey: failure.message));
        }
      },
      (savedPath) {
        emit(state.copyWith(status: UpdateStatus.readyToInstall, apkPath: savedPath));
        // Hand off to the installer right away — this is the step that suspends
        // the app while Android takes over.
        install();
      },
    );
  }

  /// Hands the downloaded APK to the system installer.
  Future<void> install() async {
    final path = state.apkPath;
    if (path == null) return;

    emit(state.copyWith(status: UpdateStatus.installing));
    final launched = await _installer.install(path);
    if (!launched) {
      // Permission denied / installer didn't open — let the user retry.
      emit(state.copyWith(status: UpdateStatus.readyToInstall, errorKey: TranslationKeys.updatePermissionDenied));
    }
    // On success the system installer is now in front of the app; nothing else
    // to do — the state stays `readyToInstall` so a retry works if the user backs out.
  }

  /// Cancels an in-flight download.
  void cancelDownload() => _cancelToken?.cancel();

  @override
  Future<void> close() {
    _pushSub?.cancel();
    _cancelToken?.cancel();
    return super.close();
  }
}
