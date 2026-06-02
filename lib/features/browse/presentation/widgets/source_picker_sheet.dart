import 'package:flutter/material.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/episode_info.dart';
import '../../domain/entities/torrent_option.dart';

/// Resolves the torrents for a single episode — every available quality,
/// most-seeded first — or an empty list when none is available anywhere. Lets
/// the picker show every episode up-front and fetch its sources only when
/// tapped.
typedef EpisodeResolver = Future<List<TorrentOption>> Function(int season, int episode);

/// Opens the source picker for a title:
///
///  * **Series** — one button per episode (from the [episodes] list, so every
///    season shows even when the torrent side only had a pack). Tapping an
///    episode resolves its sources via [onResolveEpisode], then opens a quality
///    dialog so the viewer picks the exact release. There is deliberately no
///    "full season" option.
///  * **Movie** — grouped by resolution (`4K`, `1080p`, …), with multi-film
///    collections in their own group.
///
/// Picking pops the sheet and calls [onSelected] with the magnet and a built
/// room name (e.g. `The Boys — S05E06`).
Future<void> showSourcePicker(
  BuildContext context, {
  required String title,
  required bool isSeries,
  required List<TorrentOption> torrents,
  required void Function(String magnet, String roomName) onSelected,
  List<EpisodeInfo> episodes = const [],
  EpisodeResolver? onResolveEpisode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _SourcePickerSheet(
      title: title,
      isSeries: isSeries,
      torrents: torrents,
      episodes: episodes,
      onResolveEpisode: onResolveEpisode,
      onSelected: onSelected,
    ),
  );
}

/// Per-quality buttons are capped so a popular movie with dozens of releases
/// stays scannable; the list is most-seeded first, so the best survive.
const int _maxPerQuality = 6;
const int _maxPacks = 8;
const List<String> _qualityOrder = ['4K', '1080p', '720p', '480p', 'SD'];

class _SourcePickerSheet extends StatefulWidget {
  const _SourcePickerSheet({
    required this.title,
    required this.isSeries,
    required this.torrents,
    required this.episodes,
    required this.onResolveEpisode,
    required this.onSelected,
  });

  final String title;
  final bool isSeries;
  final List<TorrentOption> torrents;
  final List<EpisodeInfo> episodes;
  final EpisodeResolver? onResolveEpisode;
  final void Function(String magnet, String roomName) onSelected;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  /// `season x episode` key of the episode currently being resolved, or null.
  String? _loadingEp;

  void _pickMovie(TorrentOption option, String roomName) {
    Navigator.of(context).pop();
    widget.onSelected(option.magnet, roomName);
  }

  Future<void> _onEpisodeTap(int season, int episode) async {
    if (_loadingEp != null) return;
    final resolver = widget.onResolveEpisode;
    if (resolver == null) return;

    setState(() => _loadingEp = '${season}x$episode');
    final options = await resolver(season, episode);
    if (!mounted) return;
    setState(() => _loadingEp = null);

    if (options.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr(TranslationKeys.torrentNotAvailable))),
        );
      return;
    }

    final epLabel = 'S${_pad(season)}E${_pad(episode)}';
    // Let the viewer choose a quality, exactly like a movie. (A single result
    // still opens the dialog so the release/size/seeders are visible first.)
    final chosen = await showEpisodeQualityDialog(
      context,
      episodeLabel: '${widget.title} — $epLabel',
      options: options,
    );
    if (chosen == null || !mounted) return;

    Navigator.of(context).pop();
    widget.onSelected(chosen.magnet, '${widget.title} — $epLabel');
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
              child: Text(
                context.tr(
                  widget.isSeries
                      ? TranslationKeys.chooseEpisode
                      : TranslationKeys.chooseQuality,
                ),
                style: context.text.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.title,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            ...widget.isSeries ? _seriesGroups(context) : _movieGroups(context),
          ],
        );
      },
    );
  }

  // ----- Series: every episode, grouped by season -----

  List<Widget> _seriesGroups(BuildContext context) {
    // season → sorted episode numbers. Prefer the authoritative Cinemeta list;
    // fall back to whatever individual episodes the torrent search returned.
    final bySeason = <int, List<int>>{};
    if (widget.episodes.isNotEmpty) {
      for (final e in widget.episodes) {
        (bySeason[e.season] ??= <int>[]).add(e.episode);
      }
    } else {
      for (final t in widget.torrents.where((t) => t.isEpisode)) {
        (bySeason[t.season!] ??= <int>[]).add(t.episode!);
      }
    }
    if (bySeason.isEmpty) {
      return [
        _header(context, context.tr(TranslationKeys.torrentNotAvailable)),
      ];
    }

    final seasons = bySeason.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final s in seasons) {
      final eps = bySeason[s]!.toSet().toList()..sort();
      widgets.add(_header(context, '${context.tr(TranslationKeys.season)} $s'));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in eps)
                _EpisodeButton(
                  label: 'E${_pad(e)}',
                  loading: _loadingEp == '${s}x$e',
                  // Block taps on other episodes while one is resolving.
                  onTap: _loadingEp == null ? () => _onEpisodeTap(s, e) : null,
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  // ----- Movie: quality buckets + collections -----

  List<Widget> _movieGroups(BuildContext context) {
    final singles = widget.torrents.where((t) => !t.isPack).toList();
    final packs = widget.torrents.where((t) => t.isPack).toList();

    final byQuality = <String, List<TorrentOption>>{};
    for (final t in singles) {
      (byQuality[t.quality] ??= <TorrentOption>[]).add(t);
    }

    final widgets = <Widget>[];
    for (final q in _qualityOrder) {
      final list = byQuality[q];
      if (list == null || list.isEmpty) continue;
      widgets.add(_header(context, q));
      for (final t in list.take(_maxPerQuality)) {
        widgets.add(_tile(
          context,
          leading: _badge(context, q),
          title: t.name.replaceAll('.', ' '),
          subtitle: _meta(t),
          onTap: () => _pickMovie(t, '${widget.title} — $q'),
        ));
      }
    }

    if (packs.isNotEmpty) {
      widgets.add(_header(context, context.tr(TranslationKeys.collectionsPacks)));
      for (final t in packs.take(_maxPacks)) {
        widgets.add(_tile(
          context,
          leading: _badge(context, t.quality),
          title: t.name.replaceAll('.', ' '),
          subtitle: _meta(t),
          onTap: () => _pickMovie(t, '${widget.title} — ${t.quality}'),
        ));
      }
    }

    return widgets;
  }

}

// ----- Shared building blocks (used by both the sheet and the quality dialog) -----

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

Widget _badge(BuildContext context, String text) => Container(
  width: 56,
  height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: context.colors.primary.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.text.labelSmall?.copyWith(
      color: context.colors.primary,
      fontWeight: FontWeight.w700,
    ),
  ),
);

Widget _tile(
  BuildContext context, {
  required Widget leading,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: leading,
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.add_rounded),
      onTap: onTap,
    ),
  );
}

/// `1080p · 3.2 GB · 166 ↑` — the size and swarm health for a single option.
String _meta(TorrentOption t) {
  final parts = <String>[
    if (t.humanSize.isNotEmpty) t.humanSize,
    '${t.seeders} ↑',
  ];
  return parts.join('  ·  ');
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// A compact season-grid button for a single episode: `E01`, with a spinner
/// while its torrent is being resolved.
class _EpisodeButton extends StatelessWidget {
  const _EpisodeButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

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

/// Modal quality picker for a single resolved episode. Groups the episode's
/// torrents by resolution (`4K`, `1080p`, …) — the same layout as the movie
/// picker — and pops with the chosen [TorrentOption], or null when dismissed.
Future<TorrentOption?> showEpisodeQualityDialog(
  BuildContext context, {
  required String episodeLabel,
  required List<TorrentOption> options,
}) {
  return showDialog<TorrentOption>(
    context: context,
    builder: (_) => _EpisodeQualityDialog(
      episodeLabel: episodeLabel,
      options: options,
    ),
  );
}

class _EpisodeQualityDialog extends StatelessWidget {
  const _EpisodeQualityDialog({
    required this.episodeLabel,
    required this.options,
  });

  /// e.g. `The Boys — S05E06`, shown under the title for context.
  final String episodeLabel;
  final List<TorrentOption> options;

  @override
  Widget build(BuildContext context) {
    final byQuality = <String, List<TorrentOption>>{};
    for (final t in options) {
      (byQuality[t.quality] ??= <TorrentOption>[]).add(t);
    }

    final groups = <Widget>[];
    for (final q in _qualityOrder) {
      final list = byQuality[q];
      if (list == null || list.isEmpty) continue;
      groups.add(_header(context, q));
      for (final t in list.take(_maxPerQuality)) {
        groups.add(_tile(
          context,
          leading: _badge(context, q),
          title: t.name.replaceAll('.', ' '),
          subtitle: _meta(t),
          onTap: () => Navigator.of(context).pop(t),
        ));
      }
    }

    return AlertDialog(
      title: Text(context.tr(TranslationKeys.chooseQuality)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              episodeLabel,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            Flexible(child: ListView(shrinkWrap: true, children: groups)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr(TranslationKeys.cancel)),
        ),
      ],
    );
  }
}
