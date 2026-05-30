import 'package:dartz/dartz.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/subtitle_result.dart';
import '../repositories/subtitles_repository.dart';

/// Downloads a chosen subtitle and returns the local file path. The caller then
/// hands that path to the room's existing subtitle upload, which broadcasts it
/// to every viewer.
class DownloadSubtitleUseCase implements UseCase<String, SubtitleResult> {
  DownloadSubtitleUseCase(this._repository);
  final SubtitlesRepository _repository;

  @override
  Future<Either<Failure, String>> call(SubtitleResult params) =>
      _repository.download(params);
}
