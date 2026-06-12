import 'package:flutter/material.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../data/datasources/cinema_remote_datasource.dart';
import '../../domain/entities/cinema_detail.dart';
import '../../domain/entities/cinema_season.dart';

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

class _SeriesSheet extends StatefulWidget {
  const _SeriesSheet({required this.title, required this.detail, required this.datasource});

  final String title;
  final CinemaDetail detail;
  final CinemaRemoteDataSource datasource;

  @override
  State<_SeriesSheet> createState() => _SeriesSheetState();
}

enum _Step { seasons, episodes }

class _SeriesSheetState extends State<_SeriesSheet> {
  _Step _step = _Step.seasons;
  bool _loading = false;
  String? _errorKey;

  late final List<CinemaSeason> _seasons = widget.detail.seasons;
  List<CinemaEpisode> _episodes = const [];
  CinemaSeason? _season;

  @override
  void initState() {
    super.initState();
    // Single season → skip the season list and load its episodes up front.
    if (_seasons.length <= 1) {
      _season = _seasons.isNotEmpty ? _seasons.first : null;
      if (_season != null) {
        _step = _Step.episodes;
        _loadEpisodes(_season!);
      }
    }
  }

  Future<void> _loadEpisodes(CinemaSeason season) async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _season = season;
      _step = _Step.episodes;
    });
    try {
      final episodes = await widget.datasource.season(season.id);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _loading = false;
        if (episodes.isEmpty) _errorKey = 'cinema_no_episodes';
      });
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKey = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKey = 'cinema_unavailable';
      });
    }
  }

  void _pickEpisode(CinemaEpisode ep) {
    final s = _season?.number ?? 0;
    final label = s > 0
        ? 'S${_pad(s)}E${_pad(ep.number)}'
        : 'E${_pad(ep.number)}';
    Navigator.of(context).pop((episode: ep, roomName: '${widget.title} — $label'));
  }

  void _back() => setState(() {
    _errorKey = null;
    _step = _Step.seasons;
  });

  bool get _canGoBack => _step == _Step.episodes && _seasons.length > 1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                if (_canGoBack)
                  IconButton(
                    onPressed: _loading ? null : _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                Expanded(
                  child: Text(
                    context.tr(_step == _Step.seasons
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
                _subtitle(),
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            ..._body(context),
          ],
        );
      },
    );
  }

  String _subtitle() {
    final parts = <String>[widget.title];
    if (_step == _Step.episodes && _season != null && _season!.number > 0) {
      parts.add('${context.tr(TranslationKeys.season)} ${_season!.number}');
    }
    return parts.join('  ›  ');
  }

  List<Widget> _body(BuildContext context) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_errorKey != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(child: Text(context.tr(_errorKey!))),
        ),
      ];
    }
    return _step == _Step.seasons ? _seasonsView(context) : _episodesView(context);
  }

  List<Widget> _seasonsView(BuildContext context) {
    if (_seasons.isEmpty) {
      return [_empty(context)];
    }
    return [
      for (final s in _seasons)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.live_tv_rounded),
            title: Text(s.name.isNotEmpty
                ? s.name
                : '${context.tr(TranslationKeys.season)} ${s.number}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _loadEpisodes(s),
          ),
        ),
    ];
  }

  List<Widget> _episodesView(BuildContext context) {
    if (_episodes.isEmpty) {
      return [_empty(context)];
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in _episodes)
            SizedBox(
              width: 72,
              child: OutlinedButton(
                onPressed: () => _pickEpisode(e),
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
