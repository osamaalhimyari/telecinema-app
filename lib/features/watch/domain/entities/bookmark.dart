import 'package:equatable/equatable.dart';

class Bookmark extends Equatable {
  const Bookmark({
    required this.id,
    required this.position,
    this.name,
  });

  final String id;
  final Duration position;
  final String? name;

  Bookmark copyWith({String? id, Duration? position, String? name}) =>
      Bookmark(
        id: id ?? this.id,
        position: position ?? this.position,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'positionMs': position.inMilliseconds,
    if (name != null) 'name': name,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'] as String,
    position: Duration(milliseconds: json['positionMs'] as int),
    name: json['name'] as String?,
  );

  @override
  List<Object?> get props => [id, position, name];
}
