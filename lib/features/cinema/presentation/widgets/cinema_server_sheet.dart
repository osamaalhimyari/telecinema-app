import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/cinema_remote_datasource.dart';
import '../../domain/entities/cinema_server.dart';
import '../../domain/entities/cinema_stream.dart';

/// The "servers of download" picker. Lists every server for a movie or episode;
/// tapping one **parses it on-device until a direct download link is found**
/// ([CinemaResolver]), then — if the server exposed more than one quality —
/// shows a quality picker, and finally hands off to the existing Create Room
/// screen with the link pre-filled in the download field.
///
/// Self-contained: it talks only to [datasource] and navigates by route, so
/// nothing in the rooms feature is touched (only its create-room route).
Future<void> showCinemaServerPicker(
  BuildContext context, {
  required String roomName,
  required List<CinemaServer> servers,
  required CinemaRemoteDataSource datasource,
  required bool isSeries,
  String? imdbId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ServerSheet(
      roomName: roomName,
      servers: servers,
      datasource: datasource,
      isSeries: isSeries,
      imdbId: imdbId,
    ),
  );
}

class _ServerSheet extends StatefulWidget {
  const _ServerSheet({
    required this.roomName,
    required this.servers,
    required this.datasource,
    required this.isSeries,
    this.imdbId,
  });

  final String roomName;
  final List<CinemaServer> servers;
  final CinemaRemoteDataSource datasource;
  final bool isSeries;
  final String? imdbId;

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  /// Index of the server currently being resolved, or null.
  int? _resolving;

  /// Most-reliable first: direct files (with a real quality), then the hosts the
  /// on-device resolver actually cracks, then everything else, with the known
  /// hard hosts (faselhd, redirectors) last. De-duplicated by link. Ordering is
  /// only a hint — every server is still tappable.
  late final List<CinemaServer> _servers = _ordered(widget.servers);

  /// Hosts the [CinemaResolver] reliably extracts (a packed `eval()` → media
  /// url). Used only to sort them ahead of the hard ones.
  static const _goodHosts = [
    'uqload', 'vidtube', 'updown', 'vidspeed', 'mp4plus',
    'anafast', 'egybestvid', 'filemoon', 'streamwish', 'mwdy',
  ];

  /// Hosts that need bespoke reverse-engineering the resolver doesn't do, so
  /// they usually fail — pushed to the bottom.
  static const _hardHosts = ['fasel', 'topcinemaa', 'filelions', 'earnvids', 'reviewrate'];

  static List<CinemaServer> _ordered(List<CinemaServer> servers) {
    final seen = <String>{};
    final unique = [
      for (final s in servers)
        if (seen.add(s.link)) s,
    ];
    int score(CinemaServer s) {
      if (s.isDirect) return 0;
      final host = Uri.tryParse(s.link)?.host ?? '';
      if (_goodHosts.any(host.contains)) return 1;
      if (_hardHosts.any(host.contains)) return 4;
      if (s.supportedHosts) return 2;
      return 3;
    }

    final indexed = [for (var i = 0; i < unique.length; i++) (i, unique[i])];
    indexed.sort((a, b) {
      final c = score(a.$2).compareTo(score(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1); // stable within a tier
    });
    return [for (final e in indexed) e.$2];
  }

  Future<void> _onTap(int index) async {
    if (_resolving != null) return;
    setState(() => _resolving = index);

    List<CinemaStream>? streams;
    try {
      streams = await widget.datasource.resolve(_servers[index]);
    } on ServerException {
      streams = null;
    } catch (_) {
      streams = null;
    }
    if (!mounted) return;
    setState(() => _resolving = null);

    if (streams == null || streams.isEmpty) {
      context.showSnack(context.tr(TranslationKeys.cinemaResolveFailed));
      return;
    }

    // One link → straight to Create Room. Several → let the viewer pick the
    // quality first ("if there is qualities show them before the room").
    final chosen = streams.length == 1
        ? streams.first
        : await _showQualityDialog(context, widget.roomName, streams);
    if (chosen == null || !mounted) return;

    // Capture the router before popping — using the sheet's context after it's
    // dismissed would look up a deactivated ancestor.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.pushNamed(
      RoutesNames.createRoom,
      extra: {
        'name': widget.roomName,
        'videoUrl': chosen.url,
        'category': widget.isSeries ? 'series' : 'movies',
        'imdbId': widget.imdbId,
      },
    );
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
                context.tr(TranslationKeys.cinemaChooseServer),
                style: context.text.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.roomName,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (_servers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(child: Text(context.tr(TranslationKeys.cinemaNoServers))),
              ),
            for (var i = 0; i < _servers.length; i++)
              _serverTile(context, i, _servers[i]),
          ],
        );
      },
    );
  }

  Widget _serverTile(BuildContext context, int index, CinemaServer server) {
    final loading = _resolving == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: _badge(context, server),
        title: Text(server.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_subtitle(context, server)),
        trailing: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        // Block other taps while one server resolves.
        onTap: _resolving == null ? () => _onTap(index) : null,
      ),
    );
  }

  Widget _badge(BuildContext context, CinemaServer server) {
    final label = server.qualityLabel ?? (server.isDirect ? 'MP4' : 'HD');
    return Container(
      width: 52,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// `Direct file · download` or `Streaming host` + an HLS hint.
  String _subtitle(BuildContext context, CinemaServer server) {
    final parts = <String>[
      if (server.isDirect)
        context.tr(TranslationKeys.cinemaDirectFile)
      else
        context.tr(TranslationKeys.cinemaStreamHost),
      if (server.hls) 'HLS',
    ];
    return parts.join('  ·  ');
  }
}

/// Quality picker shown when a single server resolves to several qualities —
/// twin of the topcinema / YouTube quality dialogs.
Future<CinemaStream?> _showQualityDialog(
  BuildContext context,
  String heading,
  List<CinemaStream> streams,
) {
  return showDialog<CinemaStream>(
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in streams)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Container(
                          width: 52,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.qualityLabel,
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(s.qualityLabel),
                        subtitle: Text(s.isHls ? 'HLS' : s.humanSize),
                        trailing: const Icon(Icons.download_rounded),
                        onTap: () => Navigator.of(dialogContext).pop(s),
                      ),
                    ),
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
