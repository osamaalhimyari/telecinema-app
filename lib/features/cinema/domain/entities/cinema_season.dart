import 'package:equatable/equatable.dart';

import '../../data/cinema_json.dart';
import 'cinema_server.dart';

/// One episode of a series. EgyBest ships the episode's `videos[]` (its servers)
/// inline in the `series/season/{id}` response, so by the time the user taps an
/// episode its [servers] are already known — no extra request.
class CinemaEpisode extends Equatable {
  const CinemaEpisode({
    required this.id,
    required this.number,
    required this.name,
    this.imdbId,
    this.servers = const [],
  });

  final int id;
  final int number;
  final String name;
  final String? imdbId;
  final List<CinemaServer> servers;

  String get label => 'E${number.toString().padLeft(2, '0')}';

  factory CinemaEpisode.fromJson(Map<String, dynamic> json) {
    return CinemaEpisode(
      id: asInt(json['id']),
      number: asInt(json['episode_number'] ?? json['number']),
      name: asString(json['name']) ?? '',
      imdbId: asString(json['imdb_external_id']),
      servers: CinemaServer.listFrom(json['videos']),
    );
  }

  @override
  List<Object?> get props => [id, number, name];
}

/// One season of a series, with its episode list. The episodes inside
/// `series/show/{id}` carry no `videos[]`; the populated list comes from
/// `series/season/{id}`, which the datasource fetches when a season is opened.
class CinemaSeason extends Equatable {
  const CinemaSeason({
    required this.id,
    required this.number,
    required this.name,
    this.episodes = const [],
  });

  final int id;
  final int number;
  final String name;
  final List<CinemaEpisode> episodes;

  CinemaSeason copyWith({List<CinemaEpisode>? episodes}) => CinemaSeason(
    id: id,
    number: number,
    name: name,
    episodes: episodes ?? this.episodes,
  );

  factory CinemaSeason.fromJson(Map<String, dynamic> json) {
    final eps = json['episodes'];
    return CinemaSeason(
      id: asInt(json['id']),
      number: asInt(json['season_number'] ?? json['number']),
      name: asString(json['name']) ?? '',
      episodes: eps is List
          ? eps
                .whereType<Map>()
                .map((e) => CinemaEpisode.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
          : const [],
    );
  }

  @override
  List<Object?> get props => [id, number, name, episodes];
}
