import 'package:dartz/dartz.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/app_update_info.dart';
import '../repositories/app_update_repository.dart';

/// The running build's identity: its Android versionCode + versionName.
typedef CurrentVersion = ({int versionCode, String versionName});

/// Checks the server for a build newer than the running one ([params]).
class CheckForUpdateUseCase implements UseCase<AppUpdateInfo, CurrentVersion> {
  CheckForUpdateUseCase(this._repository);

  final AppUpdateRepository _repository;

  @override
  Future<Either<Failure, AppUpdateInfo>> call(CurrentVersion params) =>
      _repository.check(params.versionCode, params.versionName);
}
