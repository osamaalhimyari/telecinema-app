import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '../../../data/datasources/cinema_remote_datasource.dart';
import '../../../domain/entities/cinema_server.dart';
import '../../../domain/entities/cinema_stream.dart';
import 'cinema_server_sheet_state.dart';

/// Holds the server-picker's local UI state (which server is resolving) and runs
/// the on-device resolve. Sheet-scoped: a fresh instance per picker.
class CinemaServerSheetCubit extends Cubit<CinemaServerSheetState> {
  CinemaServerSheetCubit({
    required this.datasource,
    required List<CinemaServer> servers,
  }) : super(CinemaServerSheetState(servers: _ordered(servers)));

  final CinemaRemoteDataSource datasource;

  /// Hosts the [CinemaResolver] reliably extracts (a packed `eval()` → media
  /// url). Used only to sort them ahead of the hard ones.
  static const _goodHosts = [
    'uqload', 'vidtube', 'updown', 'vidspeed', 'mp4plus',
    'anafast', 'egybestvid', 'filemoon', 'streamwish', 'mwdy',
  ];

  /// Hosts that need bespoke reverse-engineering the resolver doesn't do, so
  /// they usually fail — pushed to the bottom.
  static const _hardHosts = ['fasel', 'topcinemaa', 'filelions', 'earnvids', 'reviewrate'];

  /// Most-reliable first: direct files (with a real quality), then the hosts the
  /// on-device resolver actually cracks, then everything else, with the known
  /// hard hosts (faselhd, redirectors) last. De-duplicated by link. Ordering is
  /// only a hint — every server is still tappable.
  static List<CinemaServer> _ordered(List<CinemaServer> servers) {
    final seen = <String>{};
    final unique = [
      for (final s in servers)
        if (seen.add(s.link)) s,
    ];
    int score(CinemaServer s) {
      if (s.isDirect) return 0;
      final host = Uri.tryParse(s.link)?.host ?? '';
      if (_goodHosts.any(host.contains)) return 1;
      if (_hardHosts.any(host.contains)) return 4;
      if (s.supportedHosts) return 2;
      return 3;
    }

    final indexed = [for (var i = 0; i < unique.length; i++) (i, unique[i])];
    indexed.sort((a, b) {
      final c = score(a.$2).compareTo(score(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1); // stable within a tier
    });
    return [for (final e in indexed) e.$2];
  }

  /// Resolves the server at [index] on-device. Sets `resolving`, awaits the
  /// datasource, clears `resolving`, and returns the resolved streams (or null /
  /// empty on failure). The caller (the widget) handles the context-bound side
  /// effects — failure SnackBar, quality dialog, navigation.
  Future<List<CinemaStream>?> resolve(int index) async {
    if (state.resolving != null) return null;
    emit(state.copyWith(resolving: index));

    List<CinemaStream>? streams;
    try {
      streams = await datasource.resolve(state.servers[index]);
    } on ServerException {
      streams = null;
    } catch (_) {
      streams = null;
    }
    if (isClosed) return null;
    emit(state.copyWith(clearResolving: true));

    return streams;
  }
}
