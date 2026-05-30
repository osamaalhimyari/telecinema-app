import 'package:equatable/equatable.dart';

import '../../../domain/entities/meta_detail.dart';
import '../../../domain/entities/torrent_option.dart';

/// Loading state of the title metadata (background, description, …).
enum DetailStatus { loading, success, failure }

/// Loading state of the torrent lookup, which gates the source picker.
enum TorrentStatus { searching, found, notFound, failure }

class DetailState extends Equatable {
  const DetailState({
    this.type = 'movie',
    this.status = DetailStatus.loading,
    this.detail,
    this.errorKey,
    this.torrentStatus = TorrentStatus.searching,
    this.torrents = const [],
  });

  /// `movie` or `series` — decides how the picker groups [torrents].
  final String type;

  final DetailStatus status;
  final MetaDetail? detail;
  final String? errorKey;

  final TorrentStatus torrentStatus;

  /// Every torrent found for this title, most-seeded first. Grouped into
  /// episodes (series) or qualities (movies) by the picker.
  final List<TorrentOption> torrents;

  bool get isSeries => type == 'series';

  /// The picker is actionable only once at least one torrent has been found.
  bool get hasSources => torrentStatus == TorrentStatus.found && torrents.isNotEmpty;

  DetailState copyWith({
    String? type,
    DetailStatus? status,
    MetaDetail? detail,
    String? errorKey,
    bool clearError = false,
    TorrentStatus? torrentStatus,
    List<TorrentOption>? torrents,
  }) {
    return DetailState(
      type: type ?? this.type,
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      torrentStatus: torrentStatus ?? this.torrentStatus,
      torrents: torrents ?? this.torrents,
    );
  }

  @override
  List<Object?> get props => [type, status, detail, errorKey, torrentStatus, torrents];
}
