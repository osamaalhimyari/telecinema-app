import 'package:equatable/equatable.dart';

/// A viewer present in the room (used by both the presence list and the
/// "waiting for slow viewers" buffer gate).
class PresenceUser extends Equatable {
  const PresenceUser({required this.id, required this.name});

  final String id;
  final String name;

  factory PresenceUser.fromJson(Map<String, dynamic> json) => PresenceUser(
    id: json['id']?.toString() ?? '',
    name: (json['name'] ?? 'Anonymous').toString(),
  );

  static List<PresenceUser> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => PresenceUser.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [id, name];
}
