import 'package:equatable/equatable.dart';

/// View state for the fullscreen player overlay: whether the control stack is
/// expanded and whether the messages side-panel is open. (The controls
/// show/hide flag stays a [ValueNotifier] on the cubit because [VideoSurface]
/// and the viewer-count overlay consume it via ValueListenableBuilder.)
class FullscreenUiState extends Equatable {
  const FullscreenUiState({
    this.controlsExpanded = false,
    this.reactionsExpanded = false,
    this.messagesOpen = false,
  });

  /// The control stack (messages / mic / draw / lock) is revealed beside its
  /// toggle button.
  final bool controlsExpanded;

  /// The emoji strip is revealed beside its own (separate) toggle button.
  final bool reactionsExpanded;

  /// The messages side-panel is open.
  final bool messagesOpen;

  FullscreenUiState copyWith({
    bool? controlsExpanded,
    bool? reactionsExpanded,
    bool? messagesOpen,
  }) {
    return FullscreenUiState(
      controlsExpanded: controlsExpanded ?? this.controlsExpanded,
      reactionsExpanded: reactionsExpanded ?? this.reactionsExpanded,
      messagesOpen: messagesOpen ?? this.messagesOpen,
    );
  }

  @override
  List<Object?> get props => [controlsExpanded, reactionsExpanded, messagesOpen];
}
