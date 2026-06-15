import 'package:equatable/equatable.dart';

import '../../../domain/entities/room_type.dart';

class CreateRoomFormState extends Equatable {
  const CreateRoomFormState({
    this.type = RoomType.torrent,
    this.videoPath,
    this.videoName,
    this.category,
    this.reactions = const <String>[],
    this.reactionsExpanded = false,
  });

  final RoomType type;
  final String? videoPath;
  final String? videoName;
  final String? category;
  final List<String> reactions;

  /// Whether the (large) emoji picker grid is expanded. Collapsed by default to
  /// keep the form compact; the chosen reactions still show above it.
  final bool reactionsExpanded;

  CreateRoomFormState copyWith({
    RoomType? type,
    String? videoPath,
    String? videoName,
    String? category,
    List<String>? reactions,
    bool? reactionsExpanded,
    bool clearVideo = false,
    bool clearCategory = false,
  }) {
    return CreateRoomFormState(
      type: type ?? this.type,
      videoPath: clearVideo ? null : (videoPath ?? this.videoPath),
      videoName: clearVideo ? null : (videoName ?? this.videoName),
      category: clearCategory ? null : (category ?? this.category),
      reactions: reactions ?? this.reactions,
      reactionsExpanded: reactionsExpanded ?? this.reactionsExpanded,
    );
  }

  @override
  List<Object?> get props => [
    type,
    videoPath,
    videoName,
    category,
    reactions,
    reactionsExpanded,
  ];
}
