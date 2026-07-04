import 'package:equatable/equatable.dart';

/// View state for the fullscreen messages panel. The panel itself is stateless;
/// all of its local UI state (the input + scroll controllers) lives on
/// [FullscreenMessagesCubit], so this state is intentionally empty — it exists
/// only to give the cubit a concrete state type.
class FullscreenMessagesState extends Equatable {
  const FullscreenMessagesState();

  FullscreenMessagesState copyWith() => const FullscreenMessagesState();

  @override
  List<Object?> get props => [];
}
