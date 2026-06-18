/// A transient "someone joined / left" notice, derived in the cubit by diffing
/// successive `room_users` presence lists (the server sends the full list, not
/// discrete join/leave events). Surfaced as a brief toast over the player.
class PresenceNotice {
  const PresenceNotice({required this.name, required this.joined});

  final String name;

  /// True for a join, false for a leave.
  final bool joined;
}
