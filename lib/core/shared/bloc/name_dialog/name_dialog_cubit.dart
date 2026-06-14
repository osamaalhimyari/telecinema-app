import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'name_dialog_state.dart';

/// Owns the name-input controller for [NameDialog] and tracks whether the
/// entered name is savable (non-empty after trimming).
class NameDialogCubit extends Cubit<NameDialogState> {
  NameDialogCubit() : super(const NameDialogState()) {
    name.addListener(_onNameChanged);
  }

  final TextEditingController name = TextEditingController();

  void _onNameChanged() {
    final canSave = name.text.trim().isNotEmpty;
    if (canSave != state.canSave) emit(state.copyWith(canSave: canSave));
  }

  @override
  Future<void> close() {
    name.removeListener(_onNameChanged);
    name.dispose();
    return super.close();
  }
}
