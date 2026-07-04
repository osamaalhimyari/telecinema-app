import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'bookmark_list_sheet.dart';

/// Portrait variant — a compact icon button for the in-room control row.
/// Opens the bookmark list panel where the user can save, seek, rename or
/// delete bookmarks.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) =>
          a.isExternal != b.isExternal || a.isLive != b.isLive,
      builder: (context, state) {
        if (state.isExternal || state.isLive) return const SizedBox.shrink();
        return IconButton(
          tooltip: context.tr(TranslationKeys.bookmarks),
          onPressed: () => BookmarkListSheet.show(context),
          icon: const Icon(Icons.bookmark_border_rounded),
        );
      },
    );
  }
}

/// Fullscreen variant — a 38×38 circle that matches [FullscreenLockButton].
/// Tapping it opens/closes the [FullscreenBookmarksPanel]; the icon fills in
/// while open.
class FullscreenBookmarkButton extends StatelessWidget {
  const FullscreenBookmarkButton({
    super.key,
    required this.open,
    required this.onTap,
  });

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) =>
          a.isExternal != b.isExternal || a.isLive != b.isLive,
      builder: (context, state) {
        if (state.isExternal || state.isLive) return const SizedBox.shrink();
        return Material(
          color: open
              ? context.colors.primary.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onTap,
            child: Tooltip(
              message: context.tr(TranslationKeys.bookmarks),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  open ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
