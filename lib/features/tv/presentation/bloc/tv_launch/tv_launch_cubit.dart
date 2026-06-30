import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/livetv/live_stream.dart';
import '/features/rooms/domain/entities/create_room_params.dart';
import '/features/rooms/domain/entities/room.dart';
import '/features/rooms/domain/entities/room_type.dart';
import '/features/rooms/domain/usecases/create_room_usecase.dart';
import '../../../domain/entities/tv_channel.dart';
import 'tv_launch_state.dart';

/// Turns a tapped live-TV channel into a synced watch-party room ("watch
/// together"): packs the stream URL + headers + channel path and creates a
/// `tv` room via the existing [CreateRoomUseCase]. Returns the created [Room]
/// so the page can open it.
class TvLaunchCubit extends Cubit<TvLaunchState> {
  TvLaunchCubit(this._createRoom) : super(const TvLaunchState());

  final CreateRoomUseCase _createRoom;

  Future<Room?> launch({required TvChannel channel, required List<String> path}) async {
    if (state.busy) return null;
    emit(const TvLaunchState(busy: true));

    final logo = channel.logo;
    final params = CreateRoomParams(
      name: channel.name,
      type: RoomType.tv,
      // The packed string (stream URL + headers + channel path) is stored as the
      // room's externalUrl; clients unpack it to play and to refresh the token.
      videoUrl: LiveStreamCodec.pack(
        url: channel.url,
        headers: channel.headers,
        path: path,
      ),
      category: 'Live TV',
      // The backend validates the thumbnail as a URL — only pass a real one.
      thumbnail: (logo != null && logo.startsWith('http')) ? logo : null,
    );

    final res = await _createRoom(params);
    return res.fold(
      (failure) {
        emit(TvLaunchState(errorKey: failure.message));
        return null;
      },
      (result) {
        emit(const TvLaunchState());
        return result.room;
      },
    );
  }
}
