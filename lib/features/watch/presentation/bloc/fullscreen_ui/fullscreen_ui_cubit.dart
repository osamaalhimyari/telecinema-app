import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'fullscreen_ui_state.dart';

/// Owns all of the fullscreen player overlay's UI state, so the page can be a
/// plain StatelessWidget (no setState). Creating the cubit forces landscape +
/// immersive mode (what `initState` used to do); `close()` restores portrait +
/// the system bars (what `dispose` used to do) — both tied to the page's
/// lifetime via `BlocProvider(lazy: false)`.
class FullscreenUiCubit extends Cubit<FullscreenUiState> {
  FullscreenUiCubit() : super(const FullscreenUiState()) {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// The playback-controls show/hide flag, shared with [VideoSurface] (which
  /// toggles it on tap + auto-hides it) and the viewer-count overlay (which
  /// fades with it). Kept as a ValueNotifier because both consume it via
  /// ValueListenableBuilder; owned here so its lifetime matches the page.
  final ValueNotifier<bool> controlsVisible = ValueNotifier<bool>(true);

  /// Expands/collapses the control stack (messages / mic / draw / lock) beside
  /// its toggle button.
  void toggleControls() =>
      emit(state.copyWith(controlsExpanded: !state.controlsExpanded));

  /// Expands/collapses the emoji strip beside its own (separate) toggle button.
  void toggleReactions() =>
      emit(state.copyWith(reactionsExpanded: !state.reactionsExpanded));

  void toggleMessages() {
    final next = !state.messagesOpen;
    emit(
      state.copyWith(
        messagesOpen: next,
        bookmarksOpen: next ? false : state.bookmarksOpen,
        controlsExpanded: next ? false : state.controlsExpanded,
      ),
    );
  }

  void closeMessages() => emit(state.copyWith(messagesOpen: false));

  void toggleBookmarks() {
    final next = !state.bookmarksOpen;
    emit(
      state.copyWith(
        bookmarksOpen: next,
        messagesOpen: next ? false : state.messagesOpen,
        controlsExpanded: next ? false : state.controlsExpanded,
      ),
    );
  }

  void closeBookmarks() => emit(state.copyWith(bookmarksOpen: false));

  @override
  Future<void> close() {
    controlsVisible.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return super.close();
  }
}
