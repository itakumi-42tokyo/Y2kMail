import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kengai/services/garakei_photo_processor.dart';

Uint8List _buildTestJpeg({
  int width = 800,
  int height = 600,
  bool withGpsExif = false,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 120, 60));

  if (withGpsExif) {
    // GPSLatitudeRef（タグ番号1）に適当な値を入れ、位置情報がある状態を再現する。
    image.exif.gpsIfd.data[1] = img.IfdValueAscii('N');
  }

  return img.encodeJpg(image);
}

void main() {
  test('解像度（出力の画素数）は変更されない', () {
    for (final size in [(800, 600), (600, 1200), (1200, 600)]) {
      final input = _buildTestJpeg(width: size.$1, height: size.$2);

      final output = GarakeiPhotoProcessor.process(input);
      final decoded = img.decodeImage(output)!;

      expect(decoded.width, size.$1);
      expect(decoded.height, size.$2);
    }
  });

  test('位置情報を含むExifが残らない', () {
    final input = _buildTestJpeg(withGpsExif: true);

    final output = GarakeiPhotoProcessor.process(input);
    final decoded = img.decodeImage(output)!;

    expect(decoded.exif.isEmpty, isTrue);
  });

  test('ドット化すると、隙間（セルの角）はドット中心より暗くなる', () {
    final input = _buildTestJpeg();

    // ドットの効果を確かめたいので、ドット化以外の効果は切る。
    final output = GarakeiPhotoProcessor.process(
      input,
      brightness: 1.0,
      saturation: 1.0,
      contrast: 1.0,
      dotsAcross: 50, // 粗めにして1セルを大きくする
      glowBlurRadius: 0,
    );
    final decoded = img.decodeImage(output)!;

    final cell = (decoded.width / 50).round();
    // あるセルの中心と、その角（隙間）の明るさを比べる。
    final center = decoded.getPixel(cell ~/ 2, cell ~/ 2);
    final corner = decoded.getPixel(0, 0);

    expect(corner.r, lessThan(center.r));
  });
}
