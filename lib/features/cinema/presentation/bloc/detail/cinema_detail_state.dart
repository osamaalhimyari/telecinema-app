import 'package:equatable/equatable.dart';

import '../../../domain/entities/cinema_detail.dart';

enum CinemaDetailStatus { loading, success, failure }

/// State for the Cinema title page — just the fetched [detail] (a movie with its
/// servers, or a series with its seasons). The series season/episode drill-down
/// is handled inside the picker sheet, so it isn't part of this state.
class CinemaDetailState extends Equatable {
  const CinemaDetailState({
    this.status = CinemaDetailStatus.loading,
    this.detail,
    this.errorKey,
  });

  final CinemaDetailStatus status;
  final CinemaDetail? detail;
  final String? errorKey;

  CinemaDetailState copyWith({
    CinemaDetailStatus? status,
    CinemaDetail? detail,
    String? errorKey,
  }) {
    return CinemaDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorKey: errorKey ?? this.errorKey,
    );
  }

  @override
  List<Object?> get props => [status, detail, errorKey];
}
