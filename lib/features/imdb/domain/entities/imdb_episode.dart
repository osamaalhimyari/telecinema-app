import 'package:equatable/equatable.dart';

/// One episode's IMDb rating-card data, pulled from IMDb's GraphQL API.
class ImdbEpisode extends Equatable {
  const ImdbEpisode({
    required this.season,
    required this.episode,
    this.title,
    this.rating,
    this.votes,
    this.imageUrl,
    this.airDate,
  });

  final int season;
  final int episode;
  final String? title;

  /// IMDb aggregate rating (e.g. 8.2), or null when not yet rated (unaired).
  final double? rating;

  /// Number of user votes behind [rating], or null when not rated.
  final int? votes;

  /// Episode still image url (already sized for a card), or null.
  final String? imageUrl;

  /// Air date, or null when unknown / unannounced.
  final DateTime? airDate;

  @override
  List<Object?> get props => [season, episode, title, rating, votes, imageUrl, airDate];
}
