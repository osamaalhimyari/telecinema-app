import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '../../data/datasources/cinema_remote_datasource.dart';
import '../../domain/entities/cinema_detail.dart';
import '../../domain/entities/cinema_item.dart';
import '../bloc/detail/cinema_detail_cubit.dart';
import '../bloc/detail/cinema_detail_state.dart';
import '../widgets/cinema_series_sheet.dart';
import '../widgets/cinema_server_sheet.dart';

/// Full Cinema title page: background, poster, metadata and overview, with a
/// sticky action button that opens the "servers of download" picker (movie) or
/// the seasons/episodes drill-down (series). Visually a twin of Browse's
/// [DetailPage], but EgyBest-backed and fully isolated.
class CinemaDetailPage extends StatelessWidget {
  const CinemaDetailPage({
    super.key,
    required this.type,
    required this.id,
    this.initial,
  });

  final String type;
  final String id;

  /// Optional tile passed via `extra` so the header renders instantly while the
  /// full detail loads.
  final CinemaItem? initial;

  bool get _isSeries => type == 'series' || (initial?.isSeries ?? false);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CinemaDetailCubit>(
      create: (_) => sl<CinemaDetailCubit>()
        ..load(id: int.tryParse(id) ?? 0, isSeries: _isSeries),
      child: _CinemaDetailView(isSeries: _isSeries, initial: initial),
    );
  }
}

class _CinemaDetailView extends StatelessWidget {
  const _CinemaDetailView({required this.isSeries, this.initial});

  final bool isSeries;
  final CinemaItem? initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<CinemaDetailCubit, CinemaDetailState>(
        builder: (context, state) {
          if (state.status == CinemaDetailStatus.failure && initial == null) {
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
      bottomNavigationBar: BlocBuilder<CinemaDetailCubit, CinemaDetailState>(
        builder: (context, state) => _bottomBar(context, state),
      ),
    );
  }

  Widget _content(BuildContext context, CinemaDetailState state) {
    final detail = state.detail;
    final poster = detail?.poster ?? initial?.poster;
    final background = detail?.background ?? poster;
    final name = detail?.title ?? initial?.title ?? '';
    final year = detail?.year;
    final rating = detail?.rating ?? initial?.rating;
    final genres = detail?.genres ?? initial?.genres ?? const <String>[];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(background: _header(context, background)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _posterThumb(context, poster),
                const SizedBox(width: 16),
                Expanded(child: _titleBlock(context, name, year, rating, detail)),
              ],
            ),
          ),
        ),
        if (genres.isNotEmpty) SliverToBoxAdapter(child: _genres(context, genres)),
        if (detail?.overview != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(detail!.overview!, style: context.text.bodyMedium),
            ),
          ),
        if (state.status == CinemaDetailStatus.loading)
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
    CinemaDetail? detail,
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

  Widget _bottomBar(BuildContext context, CinemaDetailState state) {
    final detail = state.detail;
    final loading = state.status == CinemaDetailStatus.loading;
    final hasMovieSources = detail != null && !detail.isSeries && detail.servers.isNotEmpty;
    final hasSeries = detail != null && detail.isSeries && detail.seasons.isNotEmpty;
    final canPick = !loading && (hasMovieSources || hasSeries);

    final label = loading
        ? context.tr(TranslationKeys.cinemaLoading)
        : canPick
            ? context.tr(detail.isSeries
                ? TranslationKeys.chooseEpisode
                : TranslationKeys.cinemaChooseServer)
            : context.tr(TranslationKeys.cinemaNoServers);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton.icon(
        onPressed: canPick ? () => _onAction(context, detail) : null,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(canPick ? Icons.download_rounded : Icons.block_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, CinemaDetail detail) async {
    final datasource = sl<CinemaRemoteDataSource>();
    if (!detail.isSeries) {
      // Movie → straight to the servers picker.
      await showCinemaServerPicker(
        context,
        roomName: detail.title,
        servers: detail.servers,
        datasource: datasource,
        isSeries: false,
        imdbId: detail.imdbId,
      );
      return;
    }

    // Series → pick a season/episode first, then its servers.
    final pick = await showCinemaSeriesPicker(
      context,
      title: detail.title,
      detail: detail,
      datasource: datasource,
    );
    if (pick == null || !context.mounted) return;
    if (pick.episode.servers.isEmpty) {
      context.showSnack(context.tr(TranslationKeys.cinemaNoServers));
      return;
    }
    await showCinemaServerPicker(
      context,
      roomName: pick.roomName,
      servers: pick.episode.servers,
      datasource: datasource,
      isSeries: true,
      imdbId: pick.episode.imdbId ?? detail.imdbId,
    );
  }
}
