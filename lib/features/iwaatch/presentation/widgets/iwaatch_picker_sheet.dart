import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/iwaatch_remote_datasource.dart';
import '../../domain/entities/iwaatch_source.dart';

/// Entry point for the ISOLATED iwaatch "direct link" (third way).
///
/// Flow: ask for an editable movie name (the url slug, prefilled from the title)
/// → resolve it on the backend → pick a quality → create a `download` room from
/// the direct link and open it. iwaatch only has movies for now, so a series
/// just gets a short "movies only" note.
///
/// Self-contained: it talks only to [IwaatchRemoteDataSource] and navigates to
/// the Create Room screen by name. Nothing in the torrent/topcinema path is
/// touched.
Future<void> showIwaatchPicker(
  BuildContext context, {
  required String title,
  required bool isSeries,
  required IwaatchRemoteDataSource datasource,
  String? category,
  String? imdbId,
}) async {
  if (isSeries) {
    context.showSnack(context.tr(TranslationKeys.iwaatchMoviesOnly));
    return;
  }

  final name = await _askName(context, _slugify(title));
  if (name == null || name.isEmpty || !context.mounted) return;

  final source = await _pickMovie(context, datasource, name, title);
  if (source == null || !context.mounted) return;

  // Hand off to the existing Create Room screen with the resolved link in the
  // download field — that screen owns the actual download + room creation.
  context.pushNamed(
    RoutesNames.createRoom,
    extra: {
      'name': title,
      'videoUrl': source.url,
      'category': category,
      'imdbId': imdbId,
    },
  );
}

/// Title → url slug, e.g. `Back in Action` → `back-in-action`.
String _slugify(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"['’`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Prompts for the (editable) name used to locate the movie on iwaatch.
Future<String?> _askName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr(TranslationKeys.iwaatchTitle)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.iwaatchNameHint),
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.go,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.edit_rounded)),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.tr(TranslationKeys.cancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(context.tr(TranslationKeys.topcinemaGo)),
        ),
      ],
    ),
  );
}

/// Resolve by name (with a blocking spinner), then pick a quality.
Future<IwaatchSource?> _pickMovie(
  BuildContext context,
  IwaatchRemoteDataSource datasource,
  String name,
  String title,
) async {
  final sources = await _withLoading(context, () => datasource.resolveMovie(name));
  if (sources == null || !context.mounted) return null;
  if (sources.isEmpty) {
    context.showSnack(context.tr(TranslationKeys.iwaatchNotFound));
    return null;
  }
  return _showQualityDialog(context, title, sources);
}

/// Runs [task] behind a modal spinner; surfaces a snack and returns null on
/// error.
Future<T?> _withLoading<T>(BuildContext context, Future<T> Function() task) async {
  final future = task();
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final result = await future;
    if (context.mounted) Navigator.of(context).pop();
    return result;
  } on ServerException catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      context.showSnack(context.tr(e.message));
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context).pop();
      context.showSnack(context.tr(TranslationKeys.iwaatchUnavailable));
    }
    return null;
  }
}

Future<IwaatchSource?> _showQualityDialog(
  BuildContext context,
  String heading,
  List<IwaatchSource> sources,
) {
  return showDialog<IwaatchSource>(
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
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in sources)
                    _qualityTile(dialogContext, s, () => Navigator.of(dialogContext).pop(s)),
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

Widget _qualityTile(BuildContext context, IwaatchSource s, VoidCallback onTap) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Container(
        width: 56,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          s.shortLabel,
          style: context.text.labelSmall?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(s.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: s.meta.isEmpty ? null : Text(s.meta),
      trailing: const Icon(Icons.link_rounded),
      onTap: onTap,
    ),
  );
}
