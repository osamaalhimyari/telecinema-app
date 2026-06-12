/// Unpacks Dean Edwards' `p,a,c,k,e,d` packed JavaScript.
///
/// Almost every file-host embed page (uqload, vidtube, updown, reviewrate, …)
/// hides its real `.mp4` / `.m3u8` url inside a
/// `eval(function(p,a,c,k,e,d){…}('payload',base,count,'word|word|…'.split('|')…))`
/// block. This reverses that packing — substituting each base-N token back to
/// its dictionary word — so the resolver can then regex the media url out of the
/// expanded source. Pure string work; no JS engine needed.
class PackedJs {
  PackedJs._();

  static final RegExp _block = RegExp(
    r"\}\s*\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'((?:[^'\\]|\\.)*)'\.split\('\|'\)",
  );

  /// Returns the expanded source, or null when [src] contains no packed block.
  static String? unpack(String src) {
    final m = _block.firstMatch(src);
    if (m == null) return null;

    var payload = m.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\\', r'\');
    final radix = int.tryParse(m.group(2)!) ?? 0;
    final count = int.tryParse(m.group(3)!) ?? 0;
    if (radix == 0) return null;
    final words = m.group(4)!.split('|');

    var c = count;
    while (c-- > 0) {
      if (c < words.length && words[c].isNotEmpty) {
        final token = _encode(c, radix);
        payload = payload.replaceAllMapped(
          RegExp(r'\b' + RegExp.escape(token) + r'\b'),
          (_) => words[c],
        );
      }
    }
    return payload;
  }

  /// Number → base-[radix] token, matching the packer's own `e()` encoder
  /// (0-9, a-z, then A-Z for digits above 35).
  static String _encode(int c, int radix) {
    final prefix = c < radix ? '' : _encode(c ~/ radix, radix);
    final rem = c % radix;
    final suffix = rem > 35
        ? String.fromCharCode(rem + 29)
        : rem.toRadixString(36);
    return prefix + suffix;
  }
}
