import 'package:equatable/equatable.dart';

/// One subtitle candidate returned by the OpenSubtitles search, ranked by
/// [downloadsCount]. [downloadLink] points at a gzipped `.srt`; the data layer
/// fetches and unzips it before it is uploaded to the room.
class SubtitleResult extends Equatable {
  const SubtitleResult({
    required this.id,
    required this.fileName,
    required this.langId,
    required this.langName,
    required this.format,
    required this.downloadLink,
    this.releaseName = '',
    this.downloadsCount = 0,
    this.rating = 0,
  });

  /// `IDSubtitleFile` — stable per file, used as the temp filename + list key.
  final String id;
  final String fileName;

  /// ISO 639-2 code (e.g. `ara`, `eng`).
  final String langId;
  final String langName;

  /// Container format, usually `srt`.
  final String format;

  /// URL of the gzipped subtitle file.
  final String downloadLink;

  /// Release the subtitle was synced to (e.g. `The.Boys.S05E06.1080p...`).
  final String releaseName;
  final int downloadsCount;
  final double rating;

  /// Best human label for the list row.
  String get title => releaseName.isNotEmpty ? releaseName : fileName;

  @override
  List<Object?> get props => [id, fileName, langId, downloadLink];
}
