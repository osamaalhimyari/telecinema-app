import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/bookmark.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Bottom sheet that lists saved bookmarks for the current room.
/// Tap a bookmark to seek, tap the pencil to rename, tap delete to remove.
/// The "Add" button at the top saves the current video position as a bookmark.
class BookmarkListSheet extends StatelessWidget {
  const BookmarkListSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => BlocProvider.value(
          value: context.read<WatchCubit>(),
          child: const BookmarkListSheet(),
        ),
      );

  Future<void> _save(BuildContext context) async {
    await context.read<WatchCubit>().saveBookmark();
    if (!context.mounted) return;
    context.showSnack(context.tr(TranslationKeys.bookmarkSaved));
  }

  void _seek(BuildContext context, Bookmark b) {
    context.read<WatchCubit>().seekTo(b.position);
    Navigator.of(context).pop();
  }

  Future<void> _rename(BuildContext context, Bookmark b) async {
    final cubit = context.read<WatchCubit>();
    final controller = TextEditingController(text: b.name ?? '');
    final String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr(TranslationKeys.bookmarkName)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: ctx.tr(TranslationKeys.bookmarkNameHint)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.tr(TranslationKeys.cancel)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(ctx.tr(TranslationKeys.save)),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (name == null) return;
    await cubit.updateBookmark(b.id, name: name.isEmpty ? null : name);
  }

  Future<void> _delete(BuildContext context, Bookmark b) =>
      context.read<WatchCubit>().deleteBookmark(b.id);

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchCubit>();

    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.bookmarkVersion != b.bookmarkVersion,
      builder: (context, state) {
        final bookmarks = cubit.loadBookmarks();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(context.tr(TranslationKeys.bookmarks), style: context.text.titleMedium),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _save(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.tr(TranslationKeys.addBookmark)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (bookmarks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    context.tr(TranslationKeys.noBookmarks),
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = bookmarks[i];
                      return ListTile(
                        key: ValueKey(b.id),
                        leading: CircleAvatar(
                          backgroundColor: context.colors.primaryContainer,
                          child: Icon(
                            Icons.bookmark_rounded,
                            size: 18,
                            color: context.colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          b.name ?? _format(b.position),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_format(b.position)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _rename(context, b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              onPressed: () => _delete(context, b),
                            ),
                          ],
                        ),
                        onTap: () => _seek(context, b),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
