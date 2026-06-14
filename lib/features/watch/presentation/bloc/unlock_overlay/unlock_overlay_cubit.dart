import 'package:flutter_bloc/flutter_bloc.dart';

import 'unlock_overlay_state.dart';

/// Holds the password typed into the [UnlockOverlay] so the widget can stay a
/// StatelessWidget (no [TextEditingController]). The actual unlock — busy/error
/// state and the network call — lives in [WatchCubit].
class UnlockOverlayCubit extends Cubit<UnlockOverlayState> {
  UnlockOverlayCubit() : super(const UnlockOverlayState());

  void setPassword(String value) => emit(state.copyWith(password: value));
}
