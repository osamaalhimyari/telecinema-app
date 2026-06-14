import 'package:equatable/equatable.dart';

/// View state for the fullscreen player overlay: whether the control stack is
/// expanded and whether the messages side-panel is open. (The controls
/// show/hide flag stays a [ValueNotifier] on the cubit because [VideoSurface]
/// and the viewer-count overlay consume it via ValueListenableBuilder.)
class FullscreenUiState extends Equatable {
  const FullscreenUiState({
    this.controlsExpanded = false,
    this.messagesOpen = false,
    this.reactionsExpanded = false,
  });

  /// The left-side control stack (emoji / messages / mic / lock) is revealed.
  final bool controlsExpanded;

  /// The messages side-panel is open.
  final bool messagesOpen;

  /// The emoji palette's strip is expanded (vs. the single reaction icon).
  final bool reactionsExpanded;

  FullscreenUiState copyWith({
    bool? controlsExpanded,
    bool? messagesOpen,
    bool? reactionsExpanded,
  }) {
    return FullscreenUiState(
      controlsExpanded: controlsExpanded ?? this.controlsExpanded,
      messagesOpen: messagesOpen ?? this.messagesOpen,
      reactionsExpanded: reactionsExpanded ?? this.reactionsExpanded,
    );
  }

  @override
  List<Object?> get props => [controlsExpanded, messagesOpen, reactionsExpanded];
}
