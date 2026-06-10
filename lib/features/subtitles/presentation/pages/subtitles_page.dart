import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '../../domain/constants/subtitle_languages.dart';
import '../../domain/entities/subtitle_result.dart';
import '../bloc/subtitles_cubit.dart';
import '../bloc/subtitles_state.dart';

/// "Download subtitle" page: pick a language, browse OpenSubtitles results for
/// the room's title, tap one to apply it to the room (broadcast to all viewers)
/// and return to the video. Reached from the room menu's *Download subtitle*.
class SubtitlesPage extends StatelessWidget {
  const SubtitlesPage({
    super.key,
    required this.slug,
    this.imdbId,
    this.title,
    this.release,
    this.magnet,
  });

  final String slug;
  final String? imdbId;
  final String? title;

  /// The torrent/file name for this room (e.g. `Breaking.Bad.S01E07…`). Carries
  /// the season/episode the search uses to target the exact episode.
  final String? release;

  /// The room's magnet URI, if any — its `dn=` name is parsed as a fallback
  /// release name when no resolved file name is available.
  final String? magnet;

  @override
  Widget build(BuildContext context) {
    final langId = defaultSubtitleLanguageId(Localizations.localeOf(context).languageCode);
    return BlocProvider<SubtitlesCubit>(
      create: (_) => sl<SubtitlesCubit>()
        ..init(
          slug: slug,
          imdbId: imdbId,
          title: title,
          release: release,
          magnet: magnet,
          langId: langId,
        ),
      child: _SubtitlesView(imdbId: imdbId),
    );
  }
}

class _SubtitlesView extends StatelessWidget {
  const _SubtitlesView({this.imdbId});

  final String? imdbId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.downloadSubtitle))),
      body: BlocConsumer<SubtitlesCubit, SubtitlesState>(
        listenWhen: (prev, curr) =>
            prev.appliedOk != curr.appliedOk ||
            (prev.applyingId != null && curr.applyingId == null),
        listener: (context, state) {
          if (state.appliedOk) {
            // Single app-level messenger survives the pop, so the toast shows
            // back on the room page.
            context.showSnack(context.tr(TranslationKeys.subtitleAdded));
            context.pop();
          } else if (state.errorKey != null) {
            context.showSnack(context.tr(TranslationKeys.subtitleApplyFailed));
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _controls(context, state),
              const Divider(height: 1),
              Expanded(child: _results(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _controls(BuildContext context, SubtitlesState state) {
    final cubit = context.read<SubtitlesCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Manual IMDB id — the search key. Submitting it re-runs the search.
          TextFormField(
            initialValue: imdbId,
            textInputAction: TextInputAction.search,
            enabled: !state.isApplying,
            decoration: InputDecoration(
              labelText: context.tr(TranslationKeys.subtitleImdbHint),
              prefixIcon: const Icon(Icons.movie_outlined),
              border: const OutlineInputBorder(),
            ),
            onFieldSubmitted: cubit.searchByImdb,
          ),
          // Season + episode narrow the search to one TV episode. Leave blank
          // for a movie. Submitting either re-runs the search.
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: state.season?.toString(),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  enabled: !state.isApplying,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.subtitleSeasonHint),
                    prefixIcon: const Icon(Icons.tv_rounded),
                    border: const OutlineInputBorder(),
                  ),
                  onFieldSubmitted: cubit.searchBySeason,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: state.episode?.toString(),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  enabled: !state.isApplying,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.subtitleEpisodeHint),
                    prefixIcon: const Icon(Icons.theaters_rounded),
                    border: const OutlineInputBorder(),
                  ),
                  onFieldSubmitted: cubit.searchByEpisode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: state.langId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr(TranslationKeys.subtitleLanguage),
              prefixIcon: const Icon(Icons.translate_rounded),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final lang in kSubtitleLanguages)
                DropdownMenuItem(value: lang.id, child: Text(lang.label)),
            ],
            onChanged: state.isApplying
                ? null
                : (id) {
                    if (id != null) cubit.selectLanguage(id);
                  },
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, SubtitlesState state) {
    switch (state.status) {
      case SubtitlesStatus.idle:
      case SubtitlesStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.tr(TranslationKeys.subtitlesSearching)),
            ],
          ),
        );
      case SubtitlesStatus.failure:
        // Title: the translated reason; message: the same line plus a small,
        // verbatim source hint (e.g. "OpenSubtitles · HTTP 503") so the user
        // can see *why* it failed, not just that it did.
        final reason = context.tr(state.errorKey ?? TranslationKeys.errorUnknown);
        return StatusView(
          icon: Icons.cloud_off_rounded,
          title: reason,
          message: state.errorDetail == null ? null : '${state.errorDetail}',
          actionLabel: context.tr(TranslationKeys.retry),
          onAction: () => context.read<SubtitlesCubit>().search(),
        );
      case SubtitlesStatus.success:
        if (state.results.isEmpty) {
          return StatusView(
            icon: Icons.subtitles_off_outlined,
            title: context.tr(TranslationKeys.subtitlesNoResults),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: state.results.length,
          itemBuilder: (context, i) => _SubtitleTile(
            result: state.results[i],
            applying: state.applyingId == state.results[i].id,
            enabled: !state.isApplying,
            onTap: () => context.read<SubtitlesCubit>().apply(state.results[i]),
          ),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
        );
    }
  }
}

class _SubtitleTile extends StatelessWidget {
  const _SubtitleTile({
    required this.result,
    required this.applying,
    required this.enabled,
    required this.onTap,
  });

  final SubtitleResult result;
  final bool applying;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (result.downloadsCount > 0) '${result.downloadsCount} ↓',
      if (result.rating > 0) '★ ${result.rating.toStringAsFixed(1)}',
      result.format.toUpperCase(),
    ].join('  ·  ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            result.langId.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(meta),
        trailing: applying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
