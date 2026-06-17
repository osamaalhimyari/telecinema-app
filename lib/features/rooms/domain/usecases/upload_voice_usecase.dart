import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../repositories/rooms_repository.dart';

class UploadVoiceParams extends Equatable {
  const UploadVoiceParams({required this.slug, required this.filePath});
  final String slug;
  final String filePath;

  @override
  List<Object?> get props => [slug, filePath];
}

/// Uploads a recorded chat voice clip; returns the stored filename, which the
/// caller then sends in a `chat` socket event as the message's `audioUrl`.
class UploadVoiceUseCase implements UseCase<String, UploadVoiceParams> {
  UploadVoiceUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadVoiceParams params) =>
      _repository.uploadVoice(params.slug, params.filePath);
}
