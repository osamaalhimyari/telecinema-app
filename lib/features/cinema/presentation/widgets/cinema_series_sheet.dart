import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../data/datasources/cinema_remote_datasource.dart';
import '../../domain/entities/cinema_detail.dart';
import '../../domain/entities/cinema_season.dart';
import '../bloc/series/cinema_series_cubit.dart';
import '../bloc/series/cinema_series_state.dart';

/// The chosen episode plus the room name to create (carries the `S01E02` label).
typedef CinemaEpisodePick = ({CinemaEpisode episode, String roomName});

/// Series drill-down: pick a season, then an episode. Returns the chosen episode
/// (with its inline servers already loaded) so the caller can open the server
/// picker for it. A single-season series jumps straight to the episode grid.
///
/// Modeled on the topcinema seasons sheet, but EgyBest ships each episode's
/// `videos[]` inline in `series/season/{id}`, so no per-episode resolve is
/// needed before the server step.
Future<CinemaEpisodePick?> showCinemaSeriesPicker(
  BuildContext context, {
  required String title,
  required CinemaDetail detail,
  required CinemaRemoteDataSource datasource,
}) {
  return showModalBottomSheet<CinemaEpisodePick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SeriesSheet(title: title, detail: detail, datasource: datasource),
  );
}

class _SeriesSheet extends StatelessWidget {
  const _SeriesSheet({required this.title, required this.detail, required this.datasource});

  final String title;
  final CinemaDetail detail;
  final CinemaRemoteDataSource datasource;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CinemaSeriesCubit(detail.seasons, datasource)..init(),
      child: _SeriesView(title: title, seasons: detail.seasons),
    );
  }
}

class _SeriesView extends StatelessWidget {
  const _SeriesView({required this.title, required this.seasons});

  final String title;
  final List<CinemaSeason> seasons;

  void _pickEpisode(BuildContext context, CinemaSeason? season, CinemaEpisode ep) {
    final s = season?.number ?? 0;
    final label = s > 0
        ? 'S${_pad(s)}E${_pad(ep.number)}'
        : 'E${_pad(ep.number)}';
    Navigator.of(context).pop((episode: ep, roomName: '$title — $label'));
  }

  bool _canGoBack(CinemaSeriesState state) =>
      state.step == CinemaSeriesStep.episodes && seasons.length > 1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return BlocBuilder<CinemaSeriesCubit, CinemaSeriesState>(
          builder: (context, state) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    if (_canGoBack(state))
                      IconButton(
                        onPressed: state.loading
                            ? null
                            : context.read<CinemaSeriesCubit>().back,
                        icon: const Icon(Icons.arrow_back_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    Expanded(
                      child: Text(
                        context.tr(state.step == CinemaSeriesStep.seasons
                            ? TranslationKeys.chooseSeason
                            : TranslationKeys.chooseEpisode),
                        style: context.text.titleLarge,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    _subtitle(context, state),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                ..._body(context, state),
              ],
            );
          },
        );
      },
    );
  }

  String _subtitle(BuildContext context, CinemaSeriesState state) {
    final parts = <String>[title];
    final season = state.season;
    if (state.step == CinemaSeriesStep.episodes && season != null && season.number > 0) {
      parts.add('${context.tr(TranslationKeys.season)} ${season.number}');
    }
    return parts.join('  ›  ');
  }

  List<Widget> _body(BuildContext context, CinemaSeriesState state) {
    if (state.loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.errorKey != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(child: Text(context.tr(state.errorKey!))),
        ),
      ];
    }
    return state.step == CinemaSeriesStep.seasons
        ? _seasonsView(context)
        : _episodesView(context, state);
  }

  List<Widget> _seasonsView(BuildContext context) {
    if (seasons.isEmpty) {
      return [_empty(context)];
    }
    return [
      for (final s in seasons)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.live_tv_rounded),
            title: Text(s.name.isNotEmpty
                ? s.name
                : '${context.tr(TranslationKeys.season)} ${s.number}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.read<CinemaSeriesCubit>().loadEpisodes(s),
          ),
        ),
    ];
  }

  List<Widget> _episodesView(BuildContext context, CinemaSeriesState state) {
    if (state.episodes.isEmpty) {
      return [_empty(context)];
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in state.episodes)
            SizedBox(
              width: 72,
              child: OutlinedButton(
                onPressed: () => _pickEpisode(context, state.season, e),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  e.label,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(child: Text(context.tr(TranslationKeys.cinemaNoServers))),
  );

  String _pad(int n) => n.toString().padLeft(2, '0');
}
