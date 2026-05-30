import 'package:equatable/equatable.dart';

import '../../../domain/entities/meta_detail.dart';
import '../../../domain/entities/torrent_option.dart';

/// Loading state of the title metadata (background, description, …).
enum DetailStatus { loading, success, failure }

/// Loading state of the torrent lookup, which gates the Create Room button.
enum TorrentStatus { searching, found, notFound, failure }

class DetailState extends Equatable {
  const DetailState({
    this.status = DetailStatus.loading,
    this.detail,
    this.errorKey,
    this.torrentStatus = TorrentStatus.searching,
    this.torrent,
  });

  final DetailStatus status;
  final MetaDetail? detail;
  final String? errorKey;

  final TorrentStatus torrentStatus;
  final TorrentOption? torrent;

  /// The Create Room button is actionable only once a torrent is found.
  bool get canCreateRoom => torrentStatus == TorrentStatus.found && torrent != null;

  DetailState copyWith({
    DetailStatus? status,
    MetaDetail? detail,
    String? errorKey,
    bool clearError = false,
    TorrentStatus? torrentStatus,
    TorrentOption? torrent,
  }) {
    return DetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      torrentStatus: torrentStatus ?? this.torrentStatus,
      torrent: torrent ?? this.torrent,
    );
  }

  @override
  List<Object?> get props => [status, detail, errorKey, torrentStatus, torrent];
}
