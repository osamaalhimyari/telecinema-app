import 'package:flutter_bloc/flutter_bloc.dart';

import 'chat_divider_state.dart';

class ChatDividerCubit extends Cubit<ChatDividerState> {
  ChatDividerCubit() : super(const ChatDividerState());

  /// The bottom section (chat controls + input) must be at least this tall
  /// so the input field always stays visible and the user can type.
  /// This height includes the action row, reaction strip, tabs, typing
  /// indicator, and composer area.
  static const double minBottomHeight = 260;
  static const double maxFraction = 0.7;

  void setFraction(double value, {double availableHeight = 0}) {
    final min = availableHeight > 0
        ? (minBottomHeight / availableHeight).clamp(0.0, maxFraction)
        : 0.2;
    emit(state.copyWith(fraction: value.clamp(min, maxFraction)));
  }
}
