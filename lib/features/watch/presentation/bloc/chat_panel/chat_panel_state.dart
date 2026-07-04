import 'package:equatable/equatable.dart';

/// View state for the chat panel. The panel itself is stateless; all of its
/// local UI state (the input + scroll controllers) lives on [ChatPanelCubit],
/// so this state is intentionally empty — it exists only to give the cubit a
/// concrete state type.
class ChatPanelState extends Equatable {
  const ChatPanelState();

  ChatPanelState copyWith() => const ChatPanelState();

  @override
  List<Object?> get props => [];
}
