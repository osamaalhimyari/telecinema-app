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

  void toggleControls() {
    final expanding = !state.controlsExpanded;
    // Collapsing the stack also collapses the emoji strip, so it reopens tidy.
    emit(
      state.copyWith(
        controlsExpanded: expanding,
        reactionsExpanded: expanding ? state.reactionsExpanded : false,
      ),
    );
  }

  void toggleMessages() => emit(state.copyWith(messagesOpen: !state.messagesOpen));

  void closeMessages() => emit(state.copyWith(messagesOpen: false));

  void toggleReactions() => emit(state.copyWith(reactionsExpanded: !state.reactionsExpanded));

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
