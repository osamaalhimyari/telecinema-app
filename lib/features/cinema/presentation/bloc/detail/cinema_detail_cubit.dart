import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '../../../data/datasources/cinema_remote_datasource.dart';
import 'cinema_detail_state.dart';

/// Loads a single Cinema title — `media/detail/{id}` for a movie (its servers)
/// or `series/show/{id}` for a series (its seasons). Page-scoped: a fresh
/// instance per detail page.
class CinemaDetailCubit extends Cubit<CinemaDetailState> {
  CinemaDetailCubit(this._remote) : super(const CinemaDetailState());

  final CinemaRemoteDataSource _remote;

  Future<void> load({required int id, required bool isSeries}) async {
    emit(const CinemaDetailState(status: CinemaDetailStatus.loading));
    try {
      final detail = await _remote.detail(id: id, isSeries: isSeries);
      emit(CinemaDetailState(status: CinemaDetailStatus.success, detail: detail));
    } on ServerException catch (e) {
      emit(CinemaDetailState(status: CinemaDetailStatus.failure, errorKey: e.message));
    } catch (_) {
      emit(const CinemaDetailState(
        status: CinemaDetailStatus.failure,
        errorKey: 'cinema_unavailable',
      ));
    }
  }
}
