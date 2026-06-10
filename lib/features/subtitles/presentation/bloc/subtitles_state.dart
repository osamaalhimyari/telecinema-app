import 'package:equatable/equatable.dart';

import '../../domain/entities/subtitle_result.dart';

/// Loading state of the subtitle search for the currently selected language.
enum SubtitlesStatus { idle, loading, success, failure }

class SubtitlesState extends Equatable {
  const SubtitlesState({
    this.langId = 'eng',
    this.season,
    this.episode,
    this.status = SubtitlesStatus.idle,
    this.results = const [],
    this.errorKey,
    this.errorDetail,
    this.applyingId,
    this.appliedOk = false,
  });

  /// Selected OpenSubtitles language id (ISO 639-2).
  final String langId;

  /// Season / episode narrowing the search (TV titles). Null for a movie or
  /// when not yet known.
  final int? season;
  final int? episode;
  final SubtitlesStatus status;
  final List<SubtitleResult> results;

  /// Translation key of the last error (search or apply), or null.
  final String? errorKey;

  /// A short, already-readable hint about the *source* of the last error (e.g.
  /// `OpenSubtitles · HTTP 503`), shown verbatim under the translated message.
  final String? errorDetail;

  /// Id of the result currently being downloaded + applied (drives its spinner
  /// and blocks a second tap). Null when idle.
  final String? applyingId;

  /// Flips true once a subtitle has been applied to the room; the page then
  /// pops back to the video.
  final bool appliedOk;

  bool get isApplying => applyingId != null;

  SubtitlesState copyWith({
    String? langId,
    int? season,
    bool clearSeason = false,
    int? episode,
    bool clearEpisode = false,
    SubtitlesStatus? status,
    List<SubtitleResult>? results,
    String? errorKey,
    String? errorDetail,
    bool clearError = false,
    String? applyingId,
    bool clearApplying = false,
    bool? appliedOk,
  }) {
    return SubtitlesState(
      langId: langId ?? this.langId,
      season: clearSeason ? null : (season ?? this.season),
      episode: clearEpisode ? null : (episode ?? this.episode),
      status: status ?? this.status,
      results: results ?? this.results,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      applyingId: clearApplying ? null : (applyingId ?? this.applyingId),
      appliedOk: appliedOk ?? this.appliedOk,
    );
  }

  @override
  List<Object?> get props =>
      [langId, season, episode, status, results, errorKey, errorDetail, applyingId, appliedOk];
}
