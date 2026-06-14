import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../domain/entities/youtube_video.dart';
import '../bloc/youtube_search/youtube_search_cubit.dart';
import '../bloc/youtube_search/youtube_search_state.dart';
import '../widgets/youtube_picker_sheet.dart';

/// The YouTube search tab: search on-device, preview a result, then create a
/// synchronized room the server downloads (yt-dlp). An isolated feature — it
/// drives the data source directly and reuses the create-room route, touching
/// no other feature's code.
class YoutubeSearchPage extends StatelessWidget {
  const YoutubeSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => YoutubeSearchCubit(sl<YoutubeRemoteDataSource>()),
      child: const _YoutubeSearchView(),
    );
  }
}

class _YoutubeSearchView extends StatelessWidget {
  const _YoutubeSearchView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.youtubeTab))),
      body: Column(
        children: [
          _searchField(context),
          const Expanded(child: _Body()),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final cubit = context.read<YoutubeSearchCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: BlocSelector<YoutubeSearchCubit, YoutubeSearchState, bool>(
        selector: (state) => state.query.isNotEmpty,
        builder: (context, hasText) {
          return TextField(
            controller: cubit.searchController,
            textInputAction: TextInputAction.search,
            autofocus: false,
            onChanged: cubit.onChanged,
            onSubmitted: (v) => cubit.search(v.trim()),
            decoration: InputDecoration(
              isDense: true,
              hintText: context.tr(TranslationKeys.youtubeSearchHint),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: cubit.clear,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<YoutubeSearchCubit, YoutubeSearchState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorKey != null) {
          return _centered(context, context.tr(state.errorKey!));
        }
        if (state.results.isEmpty) {
          return _centered(context, context.tr(TranslationKeys.youtubeSearchPrompt));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: state.results.length,
          itemBuilder: (context, i) => _videoTile(context, state.results[i]),
        );
      },
    );
  }

  Widget _centered(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    ),
  );

  Widget _videoTile(BuildContext context, YoutubeVideo video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => startYoutubeRoomFlow(context, video, sl<YoutubeRemoteDataSource>()),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(context, video),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context, YoutubeVideo video) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Image.network(
            video.thumbnailUrl,
            width: 120,
            height: 68,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 120,
              height: 68,
              color: context.colors.surfaceContainerHighest,
              child: Icon(Icons.play_circle_outline_rounded, color: context.colors.onSurfaceVariant),
            ),
          ),
          if (video.durationLabel.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.durationLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
