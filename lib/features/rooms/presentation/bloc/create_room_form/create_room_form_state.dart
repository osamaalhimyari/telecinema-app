import 'package:equatable/equatable.dart';

import '../../../domain/entities/room_type.dart';

class CreateRoomFormState extends Equatable {
  const CreateRoomFormState({
    this.type = RoomType.torrent,
    this.videoPath,
    this.videoName,
    this.category,
    this.reactions = const <String>[],
  });

  final RoomType type;
  final String? videoPath;
  final String? videoName;
  final String? category;
  final List<String> reactions;

  CreateRoomFormState copyWith({
    RoomType? type,
    String? videoPath,
    String? videoName,
    String? category,
    List<String>? reactions,
    bool clearVideo = false,
    bool clearCategory = false,
  }) {
    return CreateRoomFormState(
      type: type ?? this.type,
      videoPath: clearVideo ? null : (videoPath ?? this.videoPath),
      videoName: clearVideo ? null : (videoName ?? this.videoName),
      category: clearCategory ? null : (category ?? this.category),
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  List<Object?> get props => [type, videoPath, videoName, category, reactions];
}
