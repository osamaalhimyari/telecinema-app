import 'package:equatable/equatable.dart';

import '../../../domain/entities/youtube_video.dart';

/// Local UI state for the YouTube search tab: whether a search is in flight,
/// an optional error/empty translation key, the current results, and the live
/// query (which the search field's clear button reads).
class YoutubeSearchState extends Equatable {
  const YoutubeSearchState({
    this.loading = false,
    this.errorKey,
    this.results = const [],
    this.query = '',
  });

  final bool loading;
  final String? errorKey;
  final List<YoutubeVideo> results;
  final String query;

  YoutubeSearchState copyWith({
    bool? loading,
    String? errorKey,
    bool clearErrorKey = false,
    List<YoutubeVideo>? results,
    String? query,
  }) {
    return YoutubeSearchState(
      loading: loading ?? this.loading,
      errorKey: clearErrorKey ? null : (errorKey ?? this.errorKey),
      results: results ?? this.results,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [loading, errorKey, results, query];
}
