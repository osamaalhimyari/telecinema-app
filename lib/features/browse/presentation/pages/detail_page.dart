import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/features/topcinema/data/datasources/topcinema_remote_datasource.dart';
import '/features/topcinema/presentation/widgets/topcinema_picker_sheet.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/meta_detail.dart';
import '../bloc/detail/detail_cubit.dart';
import '../bloc/detail/detail_state.dart';
import '../widgets/source_picker_sheet.dart';

/// Full title page: background, poster, metadata and description, with a sticky
/// Create Room button that appears once a torrent has been found.
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.type,
    required this.id,
    this.initial,
  });

  final String type;
  final String id;

  /// Optional catalogue item passed via `extra` so the header can render
  /// instantly while the full metadata loads.
  final CatalogItem? initial;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DetailCubit>(
      create: (_) => sl<DetailCubit>()
        ..load(type: type, id: id, title: initial?.name ?? ''),
      child: _DetailView(id: id, initial: initial),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.id, this.initial});

  /// IMDB id of this title (the route param) — carried into the created room so
  /// it can later search subtitles by IMDB id.
  final String id;
  final CatalogItem? initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DetailCubit, DetailState>(
        builder: (context, state) {
          if (state.status == DetailStatus.failure && initial == null) {
            return SafeArea(
              child: StatusView(
                icon: Icons.cloud_off_rounded,
                title: context.tr(TranslationKeys.errorUnknown),
                message: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
                actionLabel: context.tr(TranslationKeys.retry),
                onAction: () {},
              ),
            );
          }
          return _content(context, state);
        },
      ),
      bottomNavigationBar: BlocBuilder<DetailCubit, DetailState>(
        builder: (context, state) => _bottomBar(context, state),
      ),
    );
  }

  Widget _content(BuildContext context, DetailState state) {
    final detail = state.detail;
    final poster = detail?.poster ?? initial?.poster;
    final background = detail?.background ?? poster;
    final name = detail?.name ?? initial?.name ?? '';
    final year = detail?.releaseInfo ?? initial?.releaseInfo;
    final rating = detail?.imdbRating ?? initial?.imdbRating;
    final genres = detail?.genres ?? initial?.genres ?? const <String>[];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _header(context, background),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _posterThumb(context, poster),
                const SizedBox(width: 16),
                Expanded(
                  child: _titleBlock(context, name, year, rating, detail),
                ),
              ],
            ),
          ),
        ),
        if (genres.isNotEmpty)
          SliverToBoxAdapter(child: _genres(context, genres)),
        if (detail?.description != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(detail!.description!, style: context.text.bodyMedium),
            ),
          ),
        if (state.status == DetailStatus.loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _header(BuildContext context, String? url) {
    final fallback = Container(color: context.colors.surfaceContainerHighest);
    if (url == null) return fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
        // Scrim so the pinned app-bar icons stay legible over bright art.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                context.colors.surface.withValues(alpha: 0.85),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ],
    );
  }

  Widget _posterThumb(BuildContext context, String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 104,
        height: 156,
        child: url == null
            ? Container(color: context.colors.surfaceContainerHighest)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: context.colors.surfaceContainerHighest),
                errorWidget: (_, _, _) =>
                    Container(color: context.colors.surfaceContainerHighest),
              ),
      ),
    );
  }

  Widget _titleBlock(
    BuildContext context,
    String name,
    String? year,
    String? rating,
    MetaDetail? detail,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: context.text.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rating != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(rating, style: context.text.titleSmall),
                ],
              ),
            if (year != null) Text(year, style: context.text.bodyMedium),
            if (detail?.runtime != null)
              Text(detail!.runtime!, style: context.text.bodyMedium),
          ],
        ),
      ],
    );
  }

  Widget _genres(BuildContext context, List<String> genres) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final g in genres)
            Chip(
              label: Text(g),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, DetailState state) {
    final searching = state.torrentStatus == TorrentStatus.searching;
    // A series can be opened as soon as Cinemeta knows its episodes — even when
    // the IMDB-id torrent search found only packs (each episode resolves on
    // tap). Movies need an actual torrent result.
    final hasEpisodes = state.isSeries && (state.detail?.episodes.isNotEmpty ?? false);
    final canPick = !searching && (state.hasSources || hasEpisodes);

    final label = searching
        ? context.tr(TranslationKeys.torrentSearching)
        : canPick
            ? context.tr(
                state.isSeries
                    ? TranslationKeys.chooseEpisode
                    : TranslationKeys.chooseQuality,
              )
            : context.tr(TranslationKeys.torrentNotAvailable);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: canPick ? () => _openPicker(context, state) : null,
            icon: searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(canPick ? Icons.playlist_play_rounded : Icons.block_rounded),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 8),
          // Isolated "second way": resolve a direct download from topcinema.
          // Always available (it runs its own search), independent of torrents.
          OutlinedButton.icon(
            onPressed: () => _openTopcinema(context, state),
            icon: const Icon(Icons.download_rounded),
            label: Text(context.tr(TranslationKeys.topcinemaButton)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the standalone topcinema picker — completely separate from the
  /// torrent flow above. Resolves a direct CDN link and creates a download room.
  void _openTopcinema(BuildContext context, DetailState state) {
    final name = state.detail?.name ?? initial?.name ?? '';
    if (name.isEmpty) return;
    showTopcinemaPicker(
      context,
      title: name,
      isSeries: state.isSeries,
      datasource: sl<TopcinemaRemoteDataSource>(),
      category: state.isSeries ? 'series' : 'movies',
      imdbId: id,
    );
  }

  void _openPicker(BuildContext context, DetailState state) {
    final name = state.detail?.name ?? initial?.name ?? '';
    final cubit = context.read<DetailCubit>();
    showSourcePicker(
      context,
      title: name,
      isSeries: state.isSeries,
      torrents: state.torrents,
      episodes: state.detail?.episodes ?? const [],
      onResolveEpisode: (season, episode) =>
          cubit.resolveEpisode(seriesName: name, season: season, episode: episode),
      onSelected: (magnet, roomName) {
        context.pushNamed(
          RoutesNames.createRoom,
          extra: {
            'name': roomName,
            'magnet': magnet,
            'category': state.isSeries ? 'series' : 'movies',
            'imdbId': id,
          },
        );
      },
    );
  }
}
