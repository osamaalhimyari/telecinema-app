import 'package:equatable/equatable.dart';

/// View state for the fullscreen player overlay: whether the control stack is
/// expanded and whether the messages side-panel is open. (The controls
/// show/hide flag stays a [ValueNotifier] on the cubit because [VideoSurface]
/// and the viewer-count overlay consume it via ValueListenableBuilder.)
class FullscreenUiState extends Equatable {
  const FullscreenUiState({
    this.controlsExpanded = false,
    this.messagesOpen = false,
  });

  /// The left-side control stack (emoji strip + messages / mic / draw / lock)
  /// is revealed.
  final bool controlsExpanded;

  /// The messages side-panel is open.
  final bool messagesOpen;

  FullscreenUiState copyWith({
    bool? controlsExpanded,
    bool? messagesOpen,
  }) {
    return FullscreenUiState(
      controlsExpanded: controlsExpanded ?? this.controlsExpanded,
      messagesOpen: messagesOpen ?? this.messagesOpen,
    );
  }

  @override
  List<Object?> get props => [controlsExpanded, messagesOpen];
}
