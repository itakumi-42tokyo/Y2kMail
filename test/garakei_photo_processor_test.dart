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
  test('解像度は変更されない', () {
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

  test('赤を抑え青を足すことで、赤と青の差が元より縮まる', () {
    final input = _buildTestJpeg(); // 塗りつぶし色: r=180, g=120, b=60

    // ノイズなどランダム要素を含む効果は切り、色味の調整だけを検証する。
    final output = GarakeiPhotoProcessor.process(
      input,
      blurRadius: 0,
      noiseSigma: 0,
      vignetteAmount: 0,
      chromaticAberrationShift: 0,
      screenDoorCellSize: 0,
    );
    final decoded = img.decodeImage(output)!;
    final pixel = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);

    const originalRedBlueDiff = 180 - 60;
    final processedRedBlueDiff = pixel.r - pixel.b;

    expect(processedRedBlueDiff, lessThan(originalRedBlueDiff));
  });
}
