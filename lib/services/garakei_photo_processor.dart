import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 写真をガラケー画質に変換する、UIに依存しない純粋な処理。
/// 解像度はそのままに、彩度を下げて青みを加えた色調にし、
/// Exif（位置情報を含む）を削除する。
///
/// blur・noise・vignette・chromaticAberrationは、当時の安いレンズや
/// センサーらしさを足すための任意の調整項目（0なら効果なし）。
/// screenDoorCellSizeは、液晶の格子（ドット構造）を再現するための項目
/// （0なら効果なし。2〜4あたりが実際の格子に近い）。
///
/// 重い処理のため、実際にアプリから使うときはIsolateで実行すること
/// （GarakeiPhotoServiceを参照）。
class GarakeiPhotoProcessor {
  static Uint8List process(
    Uint8List originalBytes, {
    int quality = 90,
    int blurRadius = 2,
    double noiseSigma = 10,
    double vignetteAmount = 0.6,
    int chromaticAberrationShift = 3,
    int screenDoorCellSize = 4,
    double screenDoorDarken = 0.35,
  }) {
    final original = img.decodeImage(originalBytes);
    if (original == null) {
      throw ArgumentError('画像として読み込めませんでした');
    }

    // 当時の安価なCCDカメラらしい、彩度低め・やや青みがかった色味にする。
    var processed = img.colorOffset(
      img.adjustColor(original, saturation: 0.75, contrast: 0.92),
      red: -10,
      green: 0,
      blue: 16,
    );

    if (chromaticAberrationShift > 0) {
      processed = img.chromaticAberration(
        processed,
        shift: chromaticAberrationShift,
      );
    }
    if (blurRadius > 0) {
      processed = img.gaussianBlur(processed, radius: blurRadius);
    }
    if (noiseSigma > 0) {
      processed = img.noise(processed, noiseSigma);
    }
    if (vignetteAmount > 0) {
      processed = img.vignette(processed, amount: vignetteAmount);
    }
    if (screenDoorCellSize > 1) {
      processed = _applyScreenDoor(
        processed,
        cellSize: screenDoorCellSize,
        darken: screenDoorDarken,
      );
    }

    // Exifには位置情報などが含まれている可能性があるので明示的に消す。
    processed.exif.clear();

    return img.encodeJpg(processed, quality: quality);
  }

  // 液晶画面越しに見ているような、格子状のドット構造を重ねる。
  static img.Image _applyScreenDoor(
    img.Image src, {
    required int cellSize,
    required double darken,
  }) {
    for (var y = 0; y < src.height; y++) {
      final onGridRow = y % cellSize == 0;
      for (var x = 0; x < src.width; x++) {
        if (onGridRow || x % cellSize == 0) {
          final p = src.getPixel(x, y);
          p
            ..r = p.r * (1 - darken)
            ..g = p.g * (1 - darken)
            ..b = p.b * (1 - darken);
        }
      }
    }
    return src;
  }
}
