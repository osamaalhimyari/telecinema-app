import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../repositories/rooms_repository.dart';

class UploadVoiceParams extends Equatable {
  const UploadVoiceParams({
    required this.slug,
    required this.filePath,
    this.clientId,
    this.durationMs,
    this.name,
  });
  final String slug;
  final String filePath;
  final String? clientId;
  final int? durationMs;
  final String? name;

  @override
  List<Object?> get props => [slug, filePath, clientId, durationMs, name];
}

/// Uploads a recorded chat voice clip; the server stores it AND broadcasts the
/// chat message to the room, so the voice note is delivered by the upload alone
/// (no socket send). Returns the stored filename.
class UploadVoiceUseCase implements UseCase<String, UploadVoiceParams> {
  UploadVoiceUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadVoiceParams params) => _repository.uploadVoice(
    params.slug,
    params.filePath,
    clientId: params.clientId,
    durationMs: params.durationMs,
    name: params.name,
  );
}
