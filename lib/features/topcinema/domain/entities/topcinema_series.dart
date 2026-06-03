import 'package:equatable/equatable.dart';

/// A season of a series as parsed from the topcinema site. [url] is the season
/// page — fetch it to load that season's episodes.
class TopcinemaSeason extends Equatable {
  const TopcinemaSeason({required this.number, required this.title, required this.url});

  final int number;
  final String title;
  final String url;

  factory TopcinemaSeason.fromJson(Map<String, dynamic> json) => TopcinemaSeason(
    number: (json['number'] is num) ? (json['number'] as num).toInt() : 0,
    title: json['title']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );

  @override
  List<Object?> get props => [number, title, url];
}

/// One episode of a season. [url] is the episode page — feed it to
/// `resolveEpisode` to get the downloadable sources.
class TopcinemaEpisode extends Equatable {
  const TopcinemaEpisode({required this.number, required this.title, required this.url});

  final int number;
  final String title;
  final String url;

  factory TopcinemaEpisode.fromJson(Map<String, dynamic> json) => TopcinemaEpisode(
    number: (json['number'] is num) ? (json['number'] as num).toInt() : 0,
    title: json['title']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );

  @override
  List<Object?> get props => [number, title, url];
}

/// A parsed season page: the seasons list + the current season's episodes.
class TopcinemaSeries extends Equatable {
  const TopcinemaSeries({required this.page, required this.seasons, required this.episodes});

  final String page;
  final List<TopcinemaSeason> seasons;
  final List<TopcinemaEpisode> episodes;

  factory TopcinemaSeries.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) build) =>
        raw is List
        ? raw
              .whereType<Map>()
              .map((m) => build(Map<String, dynamic>.from(m)))
              .toList(growable: false)
        : const [];
    return TopcinemaSeries(
      page: json['page']?.toString() ?? '',
      seasons: list(json['seasons'], TopcinemaSeason.fromJson),
      episodes: list(json['episodes'], TopcinemaEpisode.fromJson),
    );
  }

  @override
  List<Object?> get props => [page, seasons, episodes];
}
