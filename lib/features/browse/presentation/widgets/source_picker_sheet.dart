import 'package:flutter/material.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/torrent_option.dart';

/// Opens the source picker for a title. The list of [torrents] is grouped two
/// different ways depending on [isSeries]:
///
///  * **Series** — by season, with one button per episode (best-seeded copy)
///    plus a "Full season" button when a season pack exists.
///  * **Movie** — by resolution (`4K`, `1080p`, …), with the multi-film
///    collections peeled into their own group.
///
/// Picking any option pops the sheet and calls [onSelected] with that option's
/// magnet and a pre-built room name (e.g. `The Boys — S05E06`).
Future<void> showSourcePicker(
  BuildContext context, {
  required String title,
  required bool isSeries,
  required List<TorrentOption> torrents,
  required void Function(String magnet, String roomName) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _SourcePickerSheet(
      title: title,
      isSeries: isSeries,
      torrents: torrents,
      onSelected: onSelected,
    ),
  );
}

/// Per-quality buttons are capped so a popular movie with dozens of releases
/// stays scannable; the list is most-seeded first, so the best survive.
const int _maxPerQuality = 6;
const int _maxPacks = 8;
const List<String> _qualityOrder = ['4K', '1080p', '720p', '480p', 'SD'];

class _SourcePickerSheet extends StatelessWidget {
  const _SourcePickerSheet({
    required this.title,
    required this.isSeries,
    required this.torrents,
    required this.onSelected,
  });

  final String title;
  final bool isSeries;
  final List<TorrentOption> torrents;
  final void Function(String magnet, String roomName) onSelected;

  void _pick(BuildContext context, TorrentOption option, String roomName) {
    Navigator.of(context).pop();
    onSelected(option.magnet, roomName);
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
                  isSeries
                      ? TranslationKeys.chooseEpisode
                      : TranslationKeys.chooseQuality,
                ),
                style: context.text.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            ...isSeries ? _seriesGroups(context) : _movieGroups(context),
          ],
        );
      },
    );
  }

  // ----- Series: season → episodes -----

  List<Widget> _seriesGroups(BuildContext context) {
    final episodes = torrents.where((t) => t.isEpisode);
    final packs = torrents.where((t) => t.isSeasonPack);
    final others = torrents.where((t) => !t.isEpisode && !t.isSeasonPack).toList();

    // season → episode → best torrent (list is seeders-desc, so first wins).
    final bySeason = <int, Map<int, TorrentOption>>{};
    for (final t in episodes) {
      (bySeason[t.season!] ??= <int, TorrentOption>{}).putIfAbsent(t.episode!, () => t);
    }
    // season → best season pack.
    final packBySeason = <int, TorrentOption>{};
    for (final t in packs) {
      packBySeason.putIfAbsent(t.season!, () => t);
    }

    final seasons = {...bySeason.keys, ...packBySeason.keys}.toList()..sort();

    final widgets = <Widget>[];
    for (final s in seasons) {
      final seasonLabel = '${context.tr(TranslationKeys.season)} $s';
      widgets.add(_header(context, seasonLabel));

      final pack = packBySeason[s];
      if (pack != null) {
        widgets.add(_tile(
          context,
          leading: _badge(context, context.tr(TranslationKeys.fullSeason)),
          title: '${context.tr(TranslationKeys.fullSeason)} · ${pack.quality}',
          subtitle: _meta(pack),
          onTap: () => _pick(context, pack, '$title — ${context.tr(TranslationKeys.season)} $s'),
        ));
      }

      final eps = bySeason[s];
      if (eps != null && eps.isNotEmpty) {
        final epNumbers = eps.keys.toList()..sort();
        widgets.add(_episodeWrap(context, s, epNumbers, eps));
      }
    }

    if (others.isNotEmpty) {
      widgets.add(_header(context, context.tr(TranslationKeys.otherSources)));
      for (final t in others.take(_maxPacks)) {
        widgets.add(_tile(
          context,
          leading: _badge(context, t.quality),
          title: t.name.replaceAll('.', ' '),
          subtitle: _meta(t),
          onTap: () => _pick(context, t, '$title — ${t.quality}'),
        ));
      }
    }

    return widgets;
  }

  Widget _episodeWrap(
    BuildContext context,
    int season,
    List<int> epNumbers,
    Map<int, TorrentOption> eps,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in epNumbers)
            _EpisodeButton(
              label: 'E${_pad(e)}',
              quality: eps[e]!.quality,
              onTap: () => _pick(
                context,
                eps[e]!,
                '$title — S${_pad(season)}E${_pad(e)}',
              ),
            ),
        ],
      ),
    );
  }

  // ----- Movie: quality buckets + collections -----

  List<Widget> _movieGroups(BuildContext context) {
    final singles = torrents.where((t) => !t.isPack).toList();
    final packs = torrents.where((t) => t.isPack).toList();

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
          onTap: () => _pick(context, t, '$title — $q'),
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
          onTap: () => _pick(context, t, '$title — ${t.quality}'),
        ));
      }
    }

    return widgets;
  }

  // ----- Shared building blocks -----

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

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

/// A compact season-grid button for a single episode: big `E01`, tiny quality.
class _EpisodeButton extends StatelessWidget {
  const _EpisodeButton({
    required this.label,
    required this.quality,
    required this.onTap,
  });

  final String label;
  final String quality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              quality,
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
