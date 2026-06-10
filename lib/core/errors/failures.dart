import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  /// A translation key (not a translated string) so the widget tree owns the
  /// locale lookup.
  final String message;

  /// An optional, already-human-readable hint about the *source* of the problem
  /// (e.g. `HTTP 500`, a server message). Not a translation key — shown verbatim
  /// under the translated [message] so the user can tell what actually failed.
  final String? detail;

  const Failure(this.message, {this.detail});

  @override
  List<Object?> get props => [message, detail];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.detail});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.detail});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message, {super.detail});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.detail});
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.detail});
}
