// One-off generator for the launcher-icon source images, drawn to match the
// app's teal brand. Run with: `dart run tool/gen_icon.dart`. It writes:
//   * assets/icon/icon.png       — full-bleed teal gradient + white play button
//   * assets/icon/foreground.png — transparent play button (Android adaptive)
// `flutter_launcher_icons` then rasterizes these into every platform's icons.
import 'dart:io';

import 'package:image/image.dart' as img;

const _src = 2048; // supersampled, downscaled to 1024 for crisp (AA) edges.
const _out = 1024;

void main() {
  Directory('assets/icon').createSync(recursive: true);
  _save('assets/icon/icon.png', _icon());
  _save('assets/icon/foreground.png', _foreground());
  stdout.writeln('Wrote assets/icon/icon.png and assets/icon/foreground.png');
}

/// Full-bleed icon: vertical teal gradient, a soft white halo, white play mark.
img.Image _icon() {
  final image = img.Image(width: _src, height: _src, numChannels: 4);
  const top = [45, 212, 191]; // #2DD4BF  teal-400
  const bottom = [13, 148, 136]; // #0D9488  teal-600
  for (var y = 0; y < _src; y++) {
    final t = y / (_src - 1);
    img.fillRect(
      image,
      x1: 0,
      y1: y,
      x2: _src - 1,
      y2: y,
      color: img.ColorRgba8(
        _lerp(top[0], bottom[0], t),
        _lerp(top[1], bottom[1], t),
        _lerp(top[2], bottom[2], t),
        255,
      ),
    );
  }
  img.fillCircle(
    image,
    x: _src ~/ 2,
    y: _src ~/ 2,
    radius: (_src * 0.30).round(),
    color: img.ColorRgba8(255, 255, 255, 38),
    antialias: true,
  );
  _play(image, scale: 1.0);
  return img.copyResize(image, width: _out, height: _out, interpolation: img.Interpolation.cubic);
}

/// Android adaptive foreground: just the play mark (smaller, inside the safe
/// zone) on a transparent canvas; the background colour is set in pubspec.
img.Image _foreground() {
  final image = img.Image(width: _src, height: _src, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  _play(image, scale: 0.7);
  return img.copyResize(image, width: _out, height: _out, interpolation: img.Interpolation.cubic);
}

/// A right-pointing "play" triangle centred on the canvas.
void _play(img.Image image, {required double scale}) {
  final cx = _src / 2;
  final cy = _src / 2;
  final r = _src * 0.26 * scale;
  img.fillPolygon(
    image,
    vertices: [
      img.Point(cx - r * 0.78, cy - r),
      img.Point(cx - r * 0.78, cy + r),
      img.Point(cx + r * 1.18, cy),
    ],
    color: img.ColorRgba8(255, 255, 255, 255),
  );
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

void _save(String path, img.Image image) => File(path).writeAsBytesSync(img.encodePng(image));
