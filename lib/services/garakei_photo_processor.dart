import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 写真をガラケー画質に変換する、UIに依存しない純粋な処理。
/// 解像度はそのままに、彩度を下げて青みを加えた色調にし、
/// Exif（位置情報を含む）を削除する。
///
/// 重い処理のため、実際にアプリから使うときはIsolateで実行すること
/// （GarakeiPhotoServiceを参照）。
class GarakeiPhotoProcessor {
  static Uint8List process(Uint8List originalBytes, {int quality = 90}) {
    final original = img.decodeImage(originalBytes);
    if (original == null) {
      throw ArgumentError('画像として読み込めませんでした');
    }

    // 当時の安価なCCDカメラらしい、彩度低め・やや青みがかった色味にする。
    final toned = img.colorOffset(
      img.adjustColor(original, saturation: 0.75, contrast: 0.92),
      red: -10,
      green: 0,
      blue: 16,
    );

    // Exifには位置情報などが含まれている可能性があるので明示的に消す。
    toned.exif.clear();

    return img.encodeJpg(toned, quality: quality);
  }
}
