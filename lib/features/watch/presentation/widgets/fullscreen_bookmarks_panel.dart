import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/bookmark.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// A translucent bookmark side-panel that slides in from the right over the
/// fullscreen video. Save the current position or tap an existing bookmark to
/// seek there. Shown/hidden by [open]; [onClose] backs the header's close button.
class FullscreenBookmarksPanel extends StatelessWidget {
  const FullscreenBookmarksPanel({
    super.key,
    required this.open,
    required this.onClose,
  });

  final bool open;
  final VoidCallback onClose;

  Future<void> _save(BuildContext context) async {
    await context.read<WatchCubit>().saveBookmark();
    if (!context.mounted) return;
    context.showSnack(context.tr(TranslationKeys.bookmarkSaved));
  }

  void _seek(BuildContext context, Bookmark b) {
    context.read<WatchCubit>().seekTo(b.position);
    onClose();
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
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = (width * 0.30).clamp(230.0, 320.0);

    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.bookmarkVersion != b.bookmarkVersion,
      builder: (context, state) {
        final bookmarks = context.read<WatchCubit>().loadBookmarks();

        return Align(
          alignment: Alignment.centerRight,
          child: AnimatedSlide(
            offset: open ? Offset.zero : const Offset(1, 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !open,
                child: SizedBox(
                  width: panelWidth,
                  height: double.infinity,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.34),
                    child: SafeArea(
                      left: false,
                      child: Column(
                        children: [
                          _header(context),
                          Expanded(child: _body(context, bookmarks)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(TranslationKeys.bookmarks),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 20),
            tooltip: context.tr(TranslationKeys.addBookmark),
            onPressed: () => _save(context),
          ),
          IconButton(
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<Bookmark> bookmarks) {
    if (bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            context.tr(TranslationKeys.noBookmarks),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: bookmarks.length,
      itemBuilder: (context, i) {
        final b = bookmarks[i];
        return Container(
          key: ValueKey(b.id),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _seek(context, b),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        b.name ?? _format(b.position),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        _format(b.position),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _rename(context, b),
                ),
                IconButton(
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  onPressed: () => _delete(context, b),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
