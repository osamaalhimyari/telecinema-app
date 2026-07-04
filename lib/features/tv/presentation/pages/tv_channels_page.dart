import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/tv_channel.dart';
import '../../domain/entities/tv_node.dart';
import 'tv_channel_preview_page.dart';

/// One level of the live-TV tree: lists [node]'s sub-groups and/or playable
/// channels. Tapping a group drills into another [TvChannelsPage]; tapping a
/// channel opens a live [TvChannelPreviewPage] where the viewer can watch it and
/// then create a synced room — the same "preview, then create a room" flow as a
/// movie. Pushed on the root navigator (above the bottom bar).
///
/// [path] is the node's name-path from the root (e.g. `["ARABIC", "EGYPTE"]`),
/// carried so a launched room can re-resolve a fresh stream token later.
class TvChannelsPage extends StatelessWidget {
  const TvChannelsPage({super.key, required this.node, this.path = const []});

  final TvNode node;
  final List<String> path;

  void _openChannel(BuildContext context, TvChannel channel, List<String> channelPath) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TvChannelPreviewPage(channel: channel, path: channelPath),
      ),
    );
  }

  void _openGroup(BuildContext context, TvNode child) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TvChannelsPage(node: child, path: [...path, child.name]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Direct channels first (rare), then sub-nodes. Each entry is either a group
    // to drill into or a leaf channel that opens its preview.
    final entries = <Widget>[
      for (final channel in node.channels)
        _ChannelTile(
          name: channel.name,
          logo: channel.logo,
          onTap: () => _openChannel(context, channel, path),
        ),
      for (final child in node.children)
        if (child.isGroup)
          _GroupTile(node: child, onTap: () => _openGroup(context, child))
        else if (child.primaryChannel != null)
          _ChannelTile(
            name: child.name,
            logo: child.displayLogo,
            onTap: () => _openChannel(context, child.primaryChannel!, [...path, child.name]),
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(node.name)),
      body: entries.isEmpty
          ? Center(
              child: Text(
                context.tr(TranslationKeys.tvEmpty),
                style: context.text.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (_, i) => entries[i],
            ),
    );
  }
}

/// A sub-group row — drills one level deeper.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.node, required this.onTap});

  final TvNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Logo(url: node.displayLogo, fallback: Icons.folder_rounded),
      title: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${node.channelCount} ${context.tr(TranslationKeys.tvChannels)}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// A playable channel row — opens its live preview.
class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.name, required this.logo, required this.onTap});

  final String name;
  final String? logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Logo(url: logo, fallback: Icons.live_tv_rounded),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.play_circle_fill_rounded, color: context.colors.primary),
      onTap: onTap,
    );
  }
}

/// Channel/group logo in a fixed box. Logos are often transparent PNGs, so they
/// sit on a light surface; a missing/broken logo falls back to an icon.
class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.fallback});

  final String? url;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(fallback, color: context.colors.primary);
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null)
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => placeholder,
              placeholder: (_, _) => placeholder,
            ),
    );
  }
}
