import 'package:equatable/equatable.dart';

import '../../domain/entities/subtitle_result.dart';

/// Loading state of the subtitle search for the currently selected language.
enum SubtitlesStatus { idle, loading, success, failure }

class SubtitlesState extends Equatable {
  const SubtitlesState({
    this.langId = 'eng',
    this.status = SubtitlesStatus.idle,
    this.results = const [],
    this.errorKey,
    this.applyingId,
    this.appliedOk = false,
  });

  /// Selected OpenSubtitles language id (ISO 639-2).
  final String langId;
  final SubtitlesStatus status;
  final List<SubtitleResult> results;

  /// Translation key of the last error (search or apply), or null.
  final String? errorKey;

  /// Id of the result currently being downloaded + applied (drives its spinner
  /// and blocks a second tap). Null when idle.
  final String? applyingId;

  /// Flips true once a subtitle has been applied to the room; the page then
  /// pops back to the video.
  final bool appliedOk;

  bool get isApplying => applyingId != null;

  SubtitlesState copyWith({
    String? langId,
    SubtitlesStatus? status,
    List<SubtitleResult>? results,
    String? errorKey,
    bool clearError = false,
    String? applyingId,
    bool clearApplying = false,
    bool? appliedOk,
  }) {
    return SubtitlesState(
      langId: langId ?? this.langId,
      status: status ?? this.status,
      results: results ?? this.results,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      applyingId: clearApplying ? null : (applyingId ?? this.applyingId),
      appliedOk: appliedOk ?? this.appliedOk,
    );
  }

  @override
  List<Object?> get props => [langId, status, results, errorKey, applyingId, appliedOk];
}
