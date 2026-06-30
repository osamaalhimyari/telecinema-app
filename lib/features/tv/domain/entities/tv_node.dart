import 'package:equatable/equatable.dart';

import 'tv_channel.dart';

/// One node in the live-TV tree. The source feed nests recursively
/// (`categories → children → … → channels`), so a node is either a **group**
/// (drills down into [children]) or a **leaf** that holds one or more playable
/// [channels]. The UI walks this generically: groups push another list, leaves
/// open the player.
class TvNode extends Equatable {
  const TvNode({
    required this.name,
    this.logo,
    this.children = const [],
    this.channels = const [],
  });

  final String name;
  final String? logo;
  final List<TvNode> children;
  final List<TvChannel> channels;

  /// A group that drills down into more nodes.
  bool get isGroup => children.isNotEmpty;

  /// A leaf that can be played directly (no sub-groups, has at least one stream).
  bool get isPlayable => children.isEmpty && channels.isNotEmpty;

  /// The stream to play for a leaf node — the first of its variants (some leaves
  /// list a couple of mirror/quality URLs); null when this node isn't a leaf.
  TvChannel? get primaryChannel => channels.isEmpty ? null : channels.first;

  /// A representative logo for a tile: the node's own, else its first channel's.
  String? get displayLogo =>
      logo ?? (channels.isEmpty ? null : channels.first.logo);

  /// Total playable channels reachable beneath this node (recursive) — drives
  /// the "N channels" subtitle on a group tile.
  int get channelCount {
    var n = channels.length;
    for (final child in children) {
      n += child.channelCount;
    }
    return n;
  }

  @override
  List<Object?> get props => [name, logo, children, channels];
}
