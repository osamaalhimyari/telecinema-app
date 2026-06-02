import 'package:dartz/dartz.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/download_progress.dart';
import '../repositories/rooms_repository.dart';

class DownloadProgressUseCase implements UseCase<DownloadProgress, String> {
  DownloadProgressUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, DownloadProgress>> call(String jobId) =>
      _repository.downloadProgress(jobId);
}
