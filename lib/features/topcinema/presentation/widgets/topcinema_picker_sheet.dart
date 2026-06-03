import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/topcinema_remote_datasource.dart';
import '../../domain/entities/topcinema_series.dart';
import '../../domain/entities/topcinema_source.dart';

/// Entry point for the ISOLATED topcinema "second way".
///
/// Flow: ask for an editable name (the url slug, prefilled from the title so the
/// user can correct it) → for a **series**, parse the site's seasons/episodes
/// and let the viewer drill in; for a **movie**, resolve directly → pick a
/// quality → create a `download` room from the direct link and open it.
///
/// Self-contained: it talks only to [TopcinemaRemoteDataSource] and navigates to
/// the room by slug. Nothing in the torrent/Cinemeta path is touched.
Future<void> showTopcinemaPicker(
  BuildContext context, {
  required String title,
  required bool isSeries,
  required TopcinemaRemoteDataSource datasource,
  String? category,
  String? imdbId,
}) async {
  final name = await _askName(context, _slugify(title));
  if (name == null || name.isEmpty || !context.mounted) return;

  _TopcinemaChoice? choice;
  if (isSeries) {
    choice = await showModalBottomSheet<_TopcinemaChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SeasonsSheet(name: name, title: title, datasource: datasource),
    );
  } else {
    choice = await _pickMovie(context, datasource, name, title);
  }
  if (choice == null || !context.mounted) return;

  // Hand off to the existing Create Room screen with the resolved link in the
  // download field, so the user can review the name / password / category
  // before creating. That screen owns the actual download + room creation.
  context.pushNamed(
    RoutesNames.createRoom,
    extra: {
      'name': choice.roomName,
      'videoUrl': choice.source.url,
      'category': category,
      'imdbId': imdbId,
    },
  );
}

/// The chosen source plus the room name to create (carries the episode label).
class _TopcinemaChoice {
  const _TopcinemaChoice(this.source, this.roomName);
  final TopcinemaSource source;
  final String roomName;
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// Title → url slug, e.g. `Widow's Bay` → `widows-bay`.
String _slugify(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"['’`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Prompts for the (editable) name used to locate the title on topcinema.
Future<String?> _askName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr(TranslationKeys.topcinemaTitle)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.topcinemaNameHint),
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.go,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.edit_rounded)),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.tr(TranslationKeys.cancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(context.tr(TranslationKeys.topcinemaGo)),
        ),
      ],
    ),
  );
}

/// Movie path: resolve by name (with a blocking spinner), then pick a quality.
Future<_TopcinemaChoice?> _pickMovie(
  BuildContext context,
  TopcinemaRemoteDataSource datasource,
  String name,
  String title,
) async {
  final sources = await _withLoading(context, () => datasource.resolveMovie(name));
  if (sources == null || !context.mounted) return null;
  if (sources.isEmpty) {
    context.showSnack(context.tr(TranslationKeys.topcinemaNotFound));
    return null;
  }
  final source = await _showQualityDialog(context, title, sources);
  return source == null ? null : _TopcinemaChoice(source, title);
}

/// Runs [task] behind a modal spinner; surfaces a snack and returns null on
/// error.
Future<T?> _withLoading<T>(BuildContext context, Future<T> Function() task) async {
  final future = task();
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final result = await future;
    if (context.mounted) Navigator.of(context).pop();
    return result;
  } on ServerException catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      context.showSnack(context.tr(e.message));
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context).pop();
      context.showSnack(context.tr(TranslationKeys.topcinemaUnavailable));
    }
    return null;
  }
}

// ===========================================================================
// Series: seasons + episodes parsed from the site
// ===========================================================================

class _SeasonsSheet extends StatefulWidget {
  const _SeasonsSheet({required this.name, required this.title, required this.datasource});

  final String name;
  final String title;
  final TopcinemaRemoteDataSource datasource;

  @override
  State<_SeasonsSheet> createState() => _SeasonsSheetState();
}

/// The drill-down step currently shown in the sheet.
enum _Step { seasons, episodes, qualities }

class _SeasonsSheetState extends State<_SeasonsSheet> {
  _Step _step = _Step.seasons;
  bool _loading = true;
  String? _errorKey;

  List<TopcinemaSeason> _seasons = const [];
  List<TopcinemaEpisode> _episodes = const [];
  List<TopcinemaSource> _sources = const [];

  TopcinemaSeason? _season;
  TopcinemaEpisode? _episode;

  @override
  void initState() {
    super.initState();
    _loadByName();
  }

  void _setError(Object error) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorKey = error is ServerException ? error.message : 'topcinema_unavailable';
    });
  }

  /// Step 1: load the title → its seasons (and the entry season's episodes). A
  /// single-season title skips straight to the episodes step.
  Future<void> _loadByName() async {
    try {
      final s = await widget.datasource.series(name: widget.name);
      if (!mounted) return;
      setState(() {
        _seasons = s.seasons;
        _errorKey = null;
        if (s.seasons.length <= 1) {
          _episodes = s.episodes;
          _season = s.seasons.isNotEmpty ? s.seasons.first : null;
          _step = _Step.episodes;
        } else {
          _step = _Step.seasons;
        }
        _loading = false;
      });
    } catch (e) {
      _setError(e);
    }
  }

  /// Step 2: a season was tapped → load and show its episodes.
  Future<void> _openSeason(TopcinemaSeason season) async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _season = season;
      _step = _Step.episodes;
    });
    try {
      final s = await widget.datasource.series(url: season.url);
      if (!mounted) return;
      setState(() {
        _episodes = s.episodes;
        if (s.seasons.isNotEmpty) _seasons = s.seasons;
        _loading = false;
      });
    } catch (e) {
      _setError(e);
    }
  }

  /// Step 3: an episode was tapped → resolve and show its qualities.
  Future<void> _openEpisode(TopcinemaEpisode ep) async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _episode = ep;
      _step = _Step.qualities;
    });
    try {
      final sources = await widget.datasource.resolveEpisode(ep.url);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
        if (sources.isEmpty) _errorKey = 'topcinema_not_found';
      });
    } catch (e) {
      _setError(e);
    }
  }

  /// Final: a quality was chosen → return it so a download room is created.
  void _pickQuality(TopcinemaSource source) {
    final label = _episode != null
        ? (_season != null
              ? 'S${_pad(_season!.number)}E${_pad(_episode!.number)}'
              : 'E${_pad(_episode!.number)}')
        : '';
    final roomName = label.isEmpty ? widget.title : '${widget.title} — $label';
    Navigator.of(context).pop(_TopcinemaChoice(source, roomName));
  }

  void _back() {
    setState(() {
      _errorKey = null;
      switch (_step) {
        case _Step.qualities:
          _step = _Step.episodes;
        case _Step.episodes:
          _step = _seasons.length > 1 ? _Step.seasons : _Step.episodes;
        case _Step.seasons:
          break;
      }
    });
  }

  bool get _canGoBack =>
      _step == _Step.qualities || (_step == _Step.episodes && _seasons.length > 1);

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
                  child: Text(_heading(context), style: context.text.titleLarge),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                _subtitle(),
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            ..._body(context),
          ],
        );
      },
    );
  }

  String _heading(BuildContext context) => switch (_step) {
    _Step.seasons => context.tr(TranslationKeys.chooseSeason),
    _Step.episodes => context.tr(TranslationKeys.chooseEpisode),
    _Step.qualities => context.tr(TranslationKeys.chooseQuality),
  };

  /// Breadcrumb under the heading: title › season › episode.
  String _subtitle() {
    final parts = <String>[widget.title];
    if (_step != _Step.seasons && _season != null) {
      parts.add(_season!.title);
    }
    if (_step == _Step.qualities && _episode != null) {
      parts.add(_episode!.title);
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
    return switch (_step) {
      _Step.seasons => _seasonsView(context),
      _Step.episodes => _episodesView(context),
      _Step.qualities => _qualitiesView(context),
    };
  }

  List<Widget> _seasonsView(BuildContext context) {
    if (_seasons.isEmpty) return _empty(context);
    return [
      for (final s in _seasons)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.live_tv_rounded),
            title: Text('${context.tr(TranslationKeys.season)} ${s.number}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSeason(s),
          ),
        ),
    ];
  }

  List<Widget> _episodesView(BuildContext context) {
    if (_episodes.isEmpty) return _empty(context);
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in _episodes)
            _EpisodeButton(
              label: 'E${_pad(e.number)}',
              loading: false,
              onTap: () => _openEpisode(e),
            ),
        ],
      ),
    ];
  }

  List<Widget> _qualitiesView(BuildContext context) {
    if (_sources.isEmpty) return _empty(context);
    return [
      for (final s in _sources) _qualityTile(context, s, () => _pickQuality(s)),
    ];
  }

  List<Widget> _empty(BuildContext context) => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(child: Text(context.tr(TranslationKeys.topcinemaNotFound))),
    ),
  ];
}

// ===========================================================================
// Shared: quality dialog + tiles
// ===========================================================================

Future<TopcinemaSource?> _showQualityDialog(
  BuildContext context,
  String heading,
  List<TopcinemaSource> sources,
) {
  return showDialog<TopcinemaSource>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr(TranslationKeys.chooseQuality)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in sources)
                    _qualityTile(dialogContext, s, () => Navigator.of(dialogContext).pop(s)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.tr(TranslationKeys.cancel)),
        ),
      ],
    ),
  );
}

Widget _qualityTile(BuildContext context, TopcinemaSource s, VoidCallback onTap) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Container(
        width: 56,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          s.shortLabel,
          style: context.text.labelSmall?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(s.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: s.meta.isEmpty ? null : Text(s.meta),
      trailing: const Icon(Icons.download_rounded),
      onTap: onTap,
    ),
  );
}

/// Compact `E01` button with a spinner while its sources resolve.
class _EpisodeButton extends StatelessWidget {
  const _EpisodeButton({required this.label, required this.loading, required this.onTap});

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
