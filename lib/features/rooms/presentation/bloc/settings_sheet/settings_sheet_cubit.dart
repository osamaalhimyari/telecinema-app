import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/config/app_config.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';
import 'settings_sheet_state.dart';

/// Outcome of a [SettingsSheetCubit.save] attempt. The widget acts on this:
/// translation, Navigator.pop and the restart SnackBar are all context-bound.
enum SettingsSaveResult {
  /// The server URL was invalid; the cubit emitted an error flag and the widget
  /// should surface the translated message via [SettingsSheetCubit.setServerError].
  invalid,

  /// Saved; the server override did not change.
  savedUnchanged,

  /// Saved; the server override changed (widget shows the restart SnackBar).
  savedChanged,
}

/// Local UI state for the account-less settings sheet: the display-name and
/// server-override text fields plus the server validation/reset state.
class SettingsSheetCubit extends Cubit<SettingsSheetState> {
  SettingsSheetCubit(this._storage, this._identity)
    : name = TextEditingController(text: _identity.state),
      // The server field shows the persisted override (what will be used after
      // the next launch), falling back to whatever is active now.
      server = TextEditingController(
        text: _storage.getString(StorageKeys.serverBaseUrl) ?? AppConfig.baseUrl,
      ),
      super(const SettingsSheetState()) {
    emit(state.copyWith(isServerDefault: _isServerDefault));
  }

  final KeyValueStorage _storage;
  final IdentityCubit _identity;

  final TextEditingController name;
  final TextEditingController server;

  bool get _isServerDefault =>
      AppConfig.normalizeUrl(server.text) == AppConfig.defaultBaseUrl;

  /// Clears any pending validation error and recomputes the reset button state.
  void onServerChanged() {
    emit(state.copyWith(clearServerError: true, isServerDefault: _isServerDefault));
  }

  void resetServer() {
    server.text = AppConfig.defaultBaseUrl;
    emit(state.copyWith(clearServerError: true, isServerDefault: _isServerDefault));
  }

  /// Sets the (already-translated) server error message. The widget supplies the
  /// string since translation is context-bound.
  void setServerError(String message) {
    emit(state.copyWith(serverError: message));
  }

  /// Validates and persists the settings. Returns the outcome so the widget can
  /// handle the context-bound bits (error translation, pop, restart SnackBar).
  Future<SettingsSaveResult> save() async {
    final raw = server.text;
    if (!AppConfig.isValidUrl(raw)) {
      return SettingsSaveResult.invalid;
    }
    final normalized = AppConfig.normalizeUrl(raw);
    final current = _storage.getString(StorageKeys.serverBaseUrl) ?? AppConfig.defaultBaseUrl;
    final changed = AppConfig.normalizeUrl(current) != normalized;

    // Store the override, or clear it when it matches the built-in default so
    // we don't pin a stale URL across future default changes.
    if (normalized == AppConfig.defaultBaseUrl) {
      await _storage.remove(StorageKeys.serverBaseUrl);
    } else {
      await _storage.setString(StorageKeys.serverBaseUrl, normalized);
    }
    if (isClosed) return changed ? SettingsSaveResult.savedChanged : SettingsSaveResult.savedUnchanged;

    await _identity.setName(name.text);
    if (isClosed) return changed ? SettingsSaveResult.savedChanged : SettingsSaveResult.savedUnchanged;

    return changed ? SettingsSaveResult.savedChanged : SettingsSaveResult.savedUnchanged;
  }

  @override
  Future<void> close() {
    name.dispose();
    server.dispose();
    return super.close();
  }
}
