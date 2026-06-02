/// Tiny JSON coercion helpers for the Browse datasources. The public catalogue
/// APIs (Cinemeta, apibay) are loosely typed — numbers arrive as strings, lists
/// are sometimes absent — so every read goes through these.
library;

/// A trimmed non-empty string, or null.
String? asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// A list of non-empty strings (e.g. `genres`), or an empty list.
List<String> asStringList(dynamic v) {
  if (v is! List) return const [];
  return v
      .map((e) => e?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// An int parsed from a num or a numeric string, defaulting to 0.
int asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString().trim() ?? '') ?? 0;
}
