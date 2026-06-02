import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../repositories/rooms_repository.dart';

class UploadSubtitleParams extends Equatable {
  const UploadSubtitleParams({required this.slug, required this.filePath});
  final String slug;
  final String filePath;

  @override
  List<Object?> get props => [slug, filePath];
}

class UploadSubtitleUseCase implements UseCase<String, UploadSubtitleParams> {
  UploadSubtitleUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadSubtitleParams params) =>
      _repository.uploadSubtitle(params.slug, params.filePath);
}
