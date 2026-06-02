import '../localization/translation_keys.dart';
import 'failures.dart';

extension FailureMessage on Failure {
  /// Maps a [Failure] onto a [TranslationKeys] entry. The failure's own
  /// `message` is already a stable key from the data layer, so prefer it and
  /// fall back per failure type.
  String get translationKey {
    if (message.startsWith('error_')) return message;
    return switch (this) {
      NotFoundFailure() => TranslationKeys.errorNotFound,
      ServerFailure() => TranslationKeys.errorServer,
      UnauthorizedFailure() => TranslationKeys.errorRequestFailed,
      CacheFailure() => TranslationKeys.errorUnknown,
      _ => TranslationKeys.errorUnknown,
    };
  }
}
