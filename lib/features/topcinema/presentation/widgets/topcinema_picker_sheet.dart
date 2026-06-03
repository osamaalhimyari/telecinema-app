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

  final slug = await _runDownload(
    context,
    datasource,
    name: choice.roomName,
    videoUrl: choice.source.url,
    category: category,
    imdbId: imdbId,
  );
  if (slug != null && context.mounted) {
    context.pushNamed(RoutesNames.room, pathParameters: {'slug': slug});
  }
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

class _SeasonsSheetState extends State<_SeasonsSheet> {
  TopcinemaSeries? _series;
  bool _loading = true;
  String? _errorKey;

  /// Currently shown season number, for highlighting the chip.
  int? _currentSeason;

  /// `season x episode` of the episode being resolved, or null.
  String? _loadingEp;

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

  Future<void> _loadByName() async {
    try {
      final s = await widget.datasource.series(name: widget.name);
      if (!mounted) return;
      setState(() {
        _series = s;
        _loading = false;
        _currentSeason = _seasonOfPage(s);
      });
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> _loadSeason(TopcinemaSeason season) async {
    setState(() {
      _loading = true;
      _currentSeason = season.number;
    });
    try {
      final s = await widget.datasource.series(url: season.url);
      if (!mounted) return;
      // Keep the full seasons list (a single-season page may omit it).
      setState(() {
        _series = TopcinemaSeries(
          page: s.page,
          seasons: s.seasons.isNotEmpty ? s.seasons : (_series?.seasons ?? const []),
          episodes: s.episodes,
        );
        _loading = false;
      });
    } catch (e) {
      _setError(e);
    }
  }

  /// Which season the parsed [page] represents, by matching its ordinal.
  int? _seasonOfPage(TopcinemaSeries s) {
    final page = Uri.decodeFull(s.page);
    for (final season in s.seasons) {
      final ord = season.title.replaceFirst('الموسم ', '').trim();
      if (ord.isNotEmpty && page.contains(ord)) return season.number;
    }
    return s.seasons.isNotEmpty ? s.seasons.first.number : null;
  }

  Future<void> _onEpisodeTap(TopcinemaEpisode ep) async {
    if (_loadingEp != null) return;
    setState(() => _loadingEp = '${_currentSeason}x${ep.number}');

    List<TopcinemaSource> sources;
    try {
      sources = await widget.datasource.resolveEpisode(ep.url);
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() => _loadingEp = null);
      context.showSnack(context.tr(e.message));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEp = null);
      context.showSnack(context.tr(TranslationKeys.topcinemaUnavailable));
      return;
    }
    if (!mounted) return;
    setState(() => _loadingEp = null);

    if (sources.isEmpty) {
      context.showSnack(context.tr(TranslationKeys.topcinemaNotFound));
      return;
    }

    final label = _currentSeason != null
        ? 'S${_pad(_currentSeason!)}E${_pad(ep.number)}'
        : 'E${_pad(ep.number)}';
    final chosen = await _showQualityDialog(context, '${widget.title} — $label', sources);
    if (chosen == null || !mounted) return;
    Navigator.of(context).pop(_TopcinemaChoice(chosen, '${widget.title} — $label'));
  }

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
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(context.tr(TranslationKeys.topcinemaTitle), style: context.text.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.title,
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            ..._body(context),
          ],
        );
      },
    );
  }

  List<Widget> _body(BuildContext context) {
    final series = _series;
    if (_errorKey != null && series == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text(context.tr(_errorKey!))),
        ),
      ];
    }
    final widgets = <Widget>[];

    if (series != null && series.seasons.length > 1) {
      widgets.add(_seasonChips(context, series.seasons));
    }

    if (_loading) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
      return widgets;
    }

    final eps = series?.episodes ?? const [];
    if (eps.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text(context.tr(TranslationKeys.topcinemaNotFound))),
        ),
      );
      return widgets;
    }

    widgets.add(_header(context, context.tr(TranslationKeys.chooseEpisode)));
    widgets.add(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in eps)
            _EpisodeButton(
              label: 'E${_pad(e.number)}',
              loading: _loadingEp == '${_currentSeason}x${e.number}',
              onTap: _loadingEp == null ? () => _onEpisodeTap(e) : null,
            ),
        ],
      ),
    );
    return widgets;
  }

  Widget _seasonChips(BuildContext context, List<TopcinemaSeason> seasons) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in seasons)
            ChoiceChip(
              label: Text('${context.tr(TranslationKeys.season)} ${s.number}'),
              selected: _currentSeason == s.number,
              onSelected: _loading || _currentSeason == s.number
                  ? null
                  : (_) => _loadSeason(s),
            ),
        ],
      ),
    );
  }
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

Widget _header(BuildContext context, String label) => Padding(
  padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
  child: Text(
    label,
    style: context.text.titleSmall?.copyWith(
      color: context.colors.primary,
      fontWeight: FontWeight.w700,
    ),
  ),
);

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

// ===========================================================================
// Download room creation + progress
// ===========================================================================

/// Creates the download room and polls its progress in a blocking dialog.
/// Returns the room slug on success, or null on failure/cancel.
Future<String?> _runDownload(
  BuildContext context,
  TopcinemaRemoteDataSource datasource, {
  required String name,
  required String videoUrl,
  String? category,
  String? imdbId,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TopcinemaDownloadDialog(
      datasource: datasource,
      name: name,
      videoUrl: videoUrl,
      category: category,
      imdbId: imdbId,
    ),
  );
}

class _TopcinemaDownloadDialog extends StatefulWidget {
  const _TopcinemaDownloadDialog({
    required this.datasource,
    required this.name,
    required this.videoUrl,
    this.category,
    this.imdbId,
  });

  final TopcinemaRemoteDataSource datasource;
  final String name;
  final String videoUrl;
  final String? category;
  final String? imdbId;

  @override
  State<_TopcinemaDownloadDialog> createState() => _TopcinemaDownloadDialogState();
}

class _TopcinemaDownloadDialogState extends State<_TopcinemaDownloadDialog> {
  int? _percent;
  String? _errorKey;
  Timer? _poll;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    String jobId;
    try {
      jobId = await widget.datasource.createDownloadRoom(
        name: widget.name,
        videoUrl: widget.videoUrl,
        category: widget.category,
        imdbId: widget.imdbId,
      );
    } on ServerException catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('error_unknown');
    }

    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_closed) return;
      try {
        final p = await widget.datasource.downloadProgress(jobId);
        if (!mounted || _closed) return;
        if (p.isError) return _fail(p.error ?? 'error_unknown');
        if (p.isDone && p.slug != null) {
          _closed = true;
          _poll?.cancel();
          Navigator.of(context).pop(p.slug);
          return;
        }
        setState(() => _percent = p.percent);
      } catch (_) {
        /* transient poll error — keep trying */
      }
    });
  }

  void _fail(String key) {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    if (!mounted) return;
    setState(() => _errorKey = key);
  }

  @override
  Widget build(BuildContext context) {
    final error = _errorKey;
    return AlertDialog(
      title: Text(context.tr(TranslationKeys.topcinemaTitle)),
      content: error != null
          ? Text(context.tr(error))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.downloadingVideo),
                        style: context.text.bodyMedium,
                      ),
                    ),
                    if (_percent != null) Text('$_percent%', style: context.text.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _percent == null ? null : _percent! / 100,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
      actions: error != null
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr(TranslationKeys.close)),
              ),
            ]
          : [
              TextButton(
                onPressed: () {
                  _closed = true;
                  _poll?.cancel();
                  Navigator.of(context).pop();
                },
                child: Text(context.tr(TranslationKeys.cancel)),
              ),
            ],
    );
  }
}
