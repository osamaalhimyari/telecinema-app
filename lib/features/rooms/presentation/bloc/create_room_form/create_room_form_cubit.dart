import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/constants/categories.dart';
import '../../../domain/entities/room_type.dart';
import 'create_room_form_state.dart';

const defaultReactions = <String>[
  '😂',
  '❤️',
  '🔥',
  '👍',
  '😮',
  '😢',
  '👏',
  '🎉',
];

const maxReactions = 8;

/// Owns the local UI state of the create-room form: the source type, the picked
/// upload video, the optional category, and the chosen reactions. A cubit is
/// stable across rebuilds, so the [TextEditingController]s and the form key live
/// here too (disposed in [close]). The async submit/upload/download still lives
/// in the separate [CreateRoomCubit].
class CreateRoomFormCubit extends Cubit<CreateRoomFormState> {
  CreateRoomFormCubit({
    String? initialName,
    String? initialMagnet,
    String? initialVideoUrl,
    String? initialCategory,
  }) : super(const CreateRoomFormState()) {
    var type = RoomType.torrent;
    String? category;

    if (initialName != null) name.text = initialName;
    if (initialMagnet != null) {
      magnet.text = initialMagnet;
      type = RoomType.torrent;
    }
    if (initialVideoUrl != null) {
      videoUrl.text = initialVideoUrl;
      type = RoomType.download;
    }
    if (initialCategory != null && kCategories.contains(initialCategory)) {
      category = initialCategory;
    }

    emit(
      state.copyWith(
        type: type,
        category: category,
        reactions: [...defaultReactions],
      ),
    );
  }

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final externalUrl = TextEditingController();
  final videoUrl = TextEditingController();
  final magnet = TextEditingController();
  final password = TextEditingController();

  void setType(RoomType type) => emit(state.copyWith(type: type));

  void setVideo(String path, String videoName) =>
      emit(state.copyWith(videoPath: path, videoName: videoName));

  /// Single-select category. Passing the already-active category clears it
  /// (category is optional).
  void setCategory(String category) => emit(
    state.category == category
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category),
  );

  void removeReaction(String emoji) {
    if (!state.reactions.contains(emoji)) return;
    emit(state.copyWith(reactions: state.reactions.where((e) => e != emoji).toList()));
  }

  /// Toggles an emoji in the selection. Returns false when the selection is full
  /// (so the widget can show the limit snack); true otherwise.
  bool toggleReaction(String emoji) {
    if (state.reactions.contains(emoji)) {
      emit(state.copyWith(reactions: state.reactions.where((e) => e != emoji).toList()));
      return true;
    } else if (state.reactions.length < maxReactions) {
      emit(state.copyWith(reactions: [...state.reactions, emoji]));
      return true;
    }
    return false;
  }

  @override
  Future<void> close() {
    name.dispose();
    externalUrl.dispose();
    videoUrl.dispose();
    magnet.dispose();
    password.dispose();
    return super.close();
  }
}
