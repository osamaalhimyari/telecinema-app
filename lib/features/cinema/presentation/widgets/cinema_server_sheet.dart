import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/cinema_remote_datasource.dart';
import '../../domain/entities/cinema_server.dart';
import '../../domain/entities/cinema_stream.dart';
import '../bloc/cinema_server_sheet/cinema_server_sheet_cubit.dart';
import '../bloc/cinema_server_sheet/cinema_server_sheet_state.dart';

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

class _ServerSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CinemaServerSheetCubit(
        datasource: datasource,
        servers: servers,
      ),
      child: _ServerSheetView(
        roomName: roomName,
        isSeries: isSeries,
        imdbId: imdbId,
      ),
    );
  }
}

class _ServerSheetView extends StatelessWidget {
  const _ServerSheetView({
    required this.roomName,
    required this.isSeries,
    this.imdbId,
  });

  final String roomName;
  final bool isSeries;
  final String? imdbId;

  Future<void> _onTap(BuildContext context, int index) async {
    final cubit = context.read<CinemaServerSheetCubit>();
    if (cubit.state.resolving != null) return;

    final streams = await cubit.resolve(index);
    if (!context.mounted) return;

    if (streams == null || streams.isEmpty) {
      context.showSnack(context.tr(TranslationKeys.cinemaResolveFailed));
      return;
    }

    // One link → straight to Create Room. Several → let the viewer pick the
    // quality first ("if there is qualities show them before the room").
    final chosen = streams.length == 1
        ? streams.first
        : await _showQualityDialog(context, roomName, streams);
    if (chosen == null || !context.mounted) return;

    // Capture the router before popping — using the sheet's context after it's
    // dismissed would look up a deactivated ancestor.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.pushNamed(
      RoutesNames.createRoom,
      extra: {
        'name': roomName,
        'videoUrl': chosen.url,
        'category': isSeries ? 'series' : 'movies',
        'imdbId': imdbId,
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
        return BlocBuilder<CinemaServerSheetCubit, CinemaServerSheetState>(
          builder: (context, state) {
            final servers = state.servers;
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
                    roomName,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (servers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: Text(context.tr(TranslationKeys.cinemaNoServers))),
                  ),
                for (var i = 0; i < servers.length; i++)
                  _serverTile(context, i, servers[i], state.resolving),
              ],
            );
          },
        );
      },
    );
  }

  Widget _serverTile(BuildContext context, int index, CinemaServer server, int? resolving) {
    final loading = resolving == index;
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
        onTap: resolving == null ? () => _onTap(context, index) : null,
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
