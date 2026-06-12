import 'package:flutter/material.dart';

/// A small badge pinned to a poster showing which catalogue a card came from —
/// the IMDB logo for Cinemeta titles, a video logo for Cinema/EgyBest titles.
///
/// The logos live in `assets/logos/` (`imdb.png` / `video.png`). Until the user
/// drops them in, a text/icon fallback renders, so the grid still works.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  /// `egybest` for the Cinema source; anything else (incl. `cinemeta`) is IMDB.
  final String source;

  bool get _isEgybest => source == 'egybest';

  @override
  Widget build(BuildContext context) {
    final asset = _isEgybest ? 'assets/logos/video.png' : 'assets/logos/imdb.png';
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    if (_isEgybest) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ondemand_video_rounded, size: 14, color: Colors.tealAccent),
          SizedBox(width: 3),
          Text(
            'Cinema',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5C518), // IMDb yellow
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'IMDb',
        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}
