import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/torrent_option.dart';
import '../../widgets/source_picker_sheet.dart';
import 'source_picker_state.dart';

/// Owns the "which episode is currently resolving" state for the source picker
/// and runs the (slow) episode resolve, so the sheet stays a StatelessWidget.
class SourcePickerCubit extends Cubit<SourcePickerState> {
  SourcePickerCubit(this._resolver) : super(const SourcePickerState());

  final EpisodeResolver? _resolver;

  /// Resolves the torrents for [season]/[episode], marking it as loading while
  /// the lookup runs. Returns the resolved options (empty when none / no
  /// resolver / already resolving) so the widget can drive the navigation and
  /// dialog. Blocks taps on other episodes while one is resolving.
  Future<List<TorrentOption>> resolveEpisode(int season, int episode) async {
    if (state.loadingEp != null) return const [];
    final resolver = _resolver;
    if (resolver == null) return const [];

    emit(state.copyWith(loadingEp: '${season}x$episode'));
    final options = await resolver(season, episode);
    if (isClosed) return const [];
    emit(state.copyWith(clearLoadingEp: true));
    return options;
  }
}
