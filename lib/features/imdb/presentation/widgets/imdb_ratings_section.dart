import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '../../data/imdb_ratings_datasource.dart';
import '../../domain/entities/imdb_episode.dart';
import '../bloc/imdb_ratings/imdb_ratings_cubit.dart';
import '../bloc/imdb_ratings/imdb_ratings_state.dart';

/// IMDb ratings dashboard shown under a title's details: a season-chip selector
/// and a horizontal row of episode cards, each with its still image and IMDb
/// rating (the same amber-star style used elsewhere in the app). Self-contained
/// — give it an IMDb id and it fetches and renders everything, collapsing to
/// nothing for movies, unknown ids or load failures.
class ImdbRatingsSection extends StatelessWidget {
  const ImdbRatingsSection({super.key, required this.imdbId});

  final String imdbId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ImdbRatingsCubit(imdbId: imdbId, datasource: sl<ImdbRatingsDataSource>()),
      child: const _RatingsView(),
    );
  }
}

class _RatingsView extends StatelessWidget {
  const _RatingsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImdbRatingsCubit, ImdbRatingsState>(
      builder: (context, state) {
        // Keep the page clean while loading, and never render an empty section.
        if (state.status == ImdbRatingsStatus.loading || state.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(state: state),
              const SizedBox(height: 12),
              _SeasonChips(state: state),
              const SizedBox(height: 12),
              _EpisodeRow(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ImdbRatingsState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(TranslationKeys.imdbEpisodesTitle),
              style: context.text.titleLarge,
            ),
          ),
          if (state.seriesRating != null) ...[
            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
            const SizedBox(width: 4),
            Text(_fmtRating(state.seriesRating!), style: context.text.titleSmall),
            if (state.seriesVotes != null) ...[
              const SizedBox(width: 4),
              Text(
                '(${_fmtVotes(state.seriesVotes!)})',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({required this.state});

  final ImdbRatingsState state;

  @override
  Widget build(BuildContext context) {
    // One season needs no selector — the episode row already speaks for itself.
    if (state.seasons.length <= 1) return const SizedBox.shrink();
    final cubit = context.read<ImdbRatingsCubit>();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.seasons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = state.seasons[i];
          return ChoiceChip(
            label: Text('${context.tr(TranslationKeys.season)} $s'),
            selected: s == state.selectedSeason,
            onSelected: (_) => cubit.selectSeason(s),
          );
        },
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.state});

  final ImdbRatingsState state;

  @override
  Widget build(BuildContext context) {
    if (state.seasonLoading) {
      return const SizedBox(
        height: _EpisodeCard.height,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final eps = state.episodes;
    if (eps.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            context.tr(TranslationKeys.imdbNoEpisodes),
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      );
    }
    return SizedBox(
      height: _EpisodeCard.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: eps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _EpisodeCard(episode: eps[i]),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode});

  final ImdbEpisode episode;

  static const double _width = 200;
  static const double height = 200;

  @override
  Widget build(BuildContext context) {
    final title = episode.title;
    final label = title != null && title.isNotEmpty
        ? '${episode.episode}. $title'
        : 'E${episode.episode}';
    return SizedBox(
      width: _width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumb(context),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          _ratingLine(context),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final fallback = Container(
      color: context.colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.tv_rounded, color: context.colors.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: episode.imageUrl == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: episode.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: context.colors.surfaceContainerHighest),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _ratingLine(BuildContext context) {
    if (episode.rating == null) {
      return Text(
        context.tr(TranslationKeys.imdbNotRated),
        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
      );
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          _fmtRating(episode.rating!),
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (episode.votes != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '(${_fmtVotes(episode.votes!)})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// `8.2` — IMDb always shows one decimal.
String _fmtRating(double r) => r.toStringAsFixed(1);

/// `22690` → `22.7K`, `396642` → `396.6K`, `1_200_000` → `1.2M`.
String _fmtVotes(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}
