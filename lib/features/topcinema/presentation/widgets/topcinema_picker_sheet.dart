import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/config/endpoints.dart';
import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/topcinema_remote_datasource.dart';
import '../../domain/entities/topcinema_source.dart';
import '../bloc/topcinema_seasons/topcinema_seasons_cubit.dart';
import '../bloc/topcinema_seasons/topcinema_seasons_state.dart';

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
  String? poster,
}) async {
  // Both domains host the same catalogue behind the same scraper, but each has
  // titles the other is missing — so let the viewer pick which mirror to search
  // (pinned, no automatic failover) instead of the code always taking the first.
  final host = await _pickHost(context);
  if (host == null || !context.mounted) return;

  final name = await _askName(context, _slugify(title));
  if (name == null || name.isEmpty || !context.mounted) return;

  _TopcinemaChoice? choice;
  if (isSeries) {
    choice = await showModalBottomSheet<_TopcinemaChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SeasonsSheet(name: name, title: title, datasource: datasource, host: host),
    );
  } else {
    choice = await _pickMovie(context, datasource, name, title, host);
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
      'thumbnail': poster,
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

/// Bottom sheet listing the configured topcinema mirrors (one button each),
/// returning the base url of the one the viewer taps. The scraper is identical
/// for every mirror — this only pins which domain it walks — so adding a host in
/// `endpoints.dart` grows this list with no other change. Returns null if
/// dismissed.
Future<String?> _pickHost(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              context.tr(TranslationKeys.topcinemaChooseSource),
              style: context.text.titleLarge,
            ),
          ),
          for (final host in Endpoints.topcinemaHosts)
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: Text(Uri.parse(host).host),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(sheetContext).pop(host),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

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
  String host,
) async {
  final sources = await _withLoading(context, () => datasource.resolveMovie(name, host: host));
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

class _SeasonsSheet extends StatelessWidget {
  const _SeasonsSheet({
    required this.name,
    required this.title,
    required this.datasource,
    required this.host,
  });

  final String name;
  final String title;
  final TopcinemaRemoteDataSource datasource;
  final String host;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TopcinemaSeasonsCubit(title: title, name: name, datasource: datasource, host: host),
      child: _SeasonsView(title: title),
    );
  }
}

class _SeasonsView extends StatelessWidget {
  const _SeasonsView({required this.title});

  final String title;

  /// Final: a quality was chosen → return it so a download room is created.
  void _pickQuality(BuildContext context, TopcinemaSource source) {
    final state = context.read<TopcinemaSeasonsCubit>().state;
    final season = state.selectedSeason;
    final episode = state.selectedEpisode;
    final label = episode != null
        ? (season != null
              ? 'S${_pad(season.number)}E${_pad(episode.number)}'
              : 'E${_pad(episode.number)}')
        : '';
    final roomName = label.isEmpty ? title : '$title — $label';
    Navigator.of(context).pop(_TopcinemaChoice(source, roomName));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return BlocBuilder<TopcinemaSeasonsCubit, TopcinemaSeasonsState>(
          builder: (context, state) {
            final cubit = context.read<TopcinemaSeasonsCubit>();
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    if (cubit.canGoBack)
                      IconButton(
                        onPressed: state.loading ? null : cubit.back,
                        icon: const Icon(Icons.arrow_back_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    Expanded(
                      child: Text(_heading(context, state), style: context.text.titleLarge),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    _subtitle(state),
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

  String _heading(BuildContext context, TopcinemaSeasonsState state) => switch (state.step) {
    TopcinemaStep.seasons => context.tr(TranslationKeys.chooseSeason),
    TopcinemaStep.episodes => context.tr(TranslationKeys.chooseEpisode),
    TopcinemaStep.qualities => context.tr(TranslationKeys.chooseQuality),
  };

  /// Breadcrumb under the heading: title › season › episode.
  String _subtitle(TopcinemaSeasonsState state) {
    final parts = <String>[title];
    if (state.step != TopcinemaStep.seasons && state.selectedSeason != null) {
      parts.add(state.selectedSeason!.title);
    }
    if (state.step == TopcinemaStep.qualities && state.selectedEpisode != null) {
      parts.add(state.selectedEpisode!.title);
    }
    return parts.join('  ›  ');
  }

  List<Widget> _body(BuildContext context, TopcinemaSeasonsState state) {
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
    return switch (state.step) {
      TopcinemaStep.seasons => _seasonsView(context, state),
      TopcinemaStep.episodes => _episodesView(context, state),
      TopcinemaStep.qualities => _qualitiesView(context, state),
    };
  }

  List<Widget> _seasonsView(BuildContext context, TopcinemaSeasonsState state) {
    if (state.seasons.isEmpty) return _empty(context);
    final cubit = context.read<TopcinemaSeasonsCubit>();
    return [
      for (final s in state.seasons)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.live_tv_rounded),
            title: Text('${context.tr(TranslationKeys.season)} ${s.number}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => cubit.openSeason(s),
          ),
        ),
    ];
  }

  List<Widget> _episodesView(BuildContext context, TopcinemaSeasonsState state) {
    if (state.episodes.isEmpty) return _empty(context);
    final cubit = context.read<TopcinemaSeasonsCubit>();
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in state.episodes)
            _EpisodeButton(
              label: 'E${_pad(e.number)}',
              loading: false,
              onTap: () => cubit.openEpisode(e),
            ),
        ],
      ),
    ];
  }

  List<Widget> _qualitiesView(BuildContext context, TopcinemaSeasonsState state) {
    if (state.sources.isEmpty) return _empty(context);
    return [
      for (final s in state.sources) _qualityTile(context, s, () => _pickQuality(context, s)),
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
