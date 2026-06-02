import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '/core/extensions/context_extensions.dart';
import '../../domain/entities/room.dart';

/// Renders a room's thumbnail. Seeded rooms use SVG placeholders; user rooms
/// have none, so we fall back to a gradient + film icon.
class RoomThumbnail extends StatelessWidget {
  const RoomThumbnail({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final url = room.thumbnailUrl;

    if (url == null) return _fallback(context);

    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        url,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => _fallback(context),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(context),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.primary.withValues(alpha: 0.30),
            context.colors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          room.isExternal ? Icons.cast_rounded : Icons.movie_outlined,
          size: 40,
          color: context.colors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
