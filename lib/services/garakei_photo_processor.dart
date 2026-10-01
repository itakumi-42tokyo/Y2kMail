import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 写真をガラケー液晶ふうに変換する、UIに依存しない純粋な処理。
/// 解像度（出力の画素数）は保ったまま、画像を丸いドットの集まりとして
/// 再構成し、ドット間の隙間を暗くすることで、液晶を間近で見ているような
/// つやのある質感を作る。あわせてExif（位置情報を含む）を削除する。
///
/// dotsAcross: 横方向に並べるドットの数（多いほど細かい）。0でドット化しない。
/// dotFill: 1セルの中でドットが占める割合（0〜1）。
/// gapDarken: ドット間の隙間の暗さ（0=真っ暗、1=暗くしない）。
/// glowBlurRadius: 明るい部分をにじませて光らせる（0で効果なし）。
///
/// 重い処理のため、実際にアプリから使うときはIsolateで実行すること
/// （GarakeiPhotoServiceを参照）。
class GarakeiPhotoProcessor {
  static Uint8List process(
    Uint8List originalBytes, {
    int quality = 92,
    double brightness = 1.12,
    double saturation = 1.15,
    double contrast = 1.05,
    int targetWidth = 0,
    // ドットの密度（横に並ぶドット数）。小さいほど粗い。
    // UIと連動する見た目の要なので、今後ここを起点に調整する。暫定で100。
    int dotsAcross = 100,
    double dotFill = 0.85,
    double gapDarken = 0.35,
    int glowBlurRadius = 0,
    double glowThreshold = 0.7,
  }) {
    final original = img.decodeImage(originalBytes);
    if (original == null) {
      throw ArgumentError('画像として読み込めませんでした');
    }

    // 液晶らしく、やや鮮やかで明るめの発色にする。
    var processed = img.adjustColor(
      original,
      saturation: saturation,
      contrast: contrast,
      brightness: brightness,
    );

    // targetWidthが指定されていれば、ガラケー画面サイズなどへ縮小する。
    if (targetWidth > 0 && targetWidth < processed.width) {
      processed = img.copyResize(processed, width: targetWidth);
    }

    if (glowBlurRadius > 0) {
      processed = _applyGlow(
        processed,
        threshold: glowThreshold,
        blurRadius: glowBlurRadius,
      );
    }
    if (dotsAcross > 0) {
      processed = _applyLcdDots(
        processed,
        dotsAcross: dotsAcross,
        dotFill: dotFill,
        gapDarken: gapDarken,
      );
    }

    // Exifには位置情報などが含まれている可能性があるので明示的に消す。
    processed.exif.clear();

    return img.encodeJpg(processed, quality: quality);
  }

  // 明るい部分（ハイライト）だけを抽出してぼかし、
  // 元の画像に光として重ねる（ブルーム）。つやを足す。
  static img.Image _applyGlow(
    img.Image src, {
    required double threshold,
    required int blurRadius,
  }) {
    final brightAreas = img.luminanceThreshold(
      src.clone(),
      threshold: threshold,
      outputColor: true,
    );
    final glow = img.gaussianBlur(brightAreas, radius: blurRadius);
    return img.compositeImage(src, glow, blend: img.BlendMode.screen);
  }

  // 画像を丸いドットの集まりとして描き直す。
  // 各セルはそのセル中心の色を持つ丸いドットになり、
  // セル間の隙間は暗くなる。これで液晶の画素感を作る。
  static img.Image _applyLcdDots(
    img.Image src, {
    required int dotsAcross,
    required double dotFill,
    required double gapDarken,
  }) {
    final cell = (src.width / dotsAcross).round().clamp(2, 64);
    final source = src.clone(); // 色のサンプリング元（書き込みと分離する）
    final half = cell / 2.0;
    final dotRadius = cell * dotFill / 2.0;

    for (var y = 0; y < src.height; y++) {
      final cellCenterY = (y ~/ cell) * cell + half;
      final sampleY = cellCenterY.floor().clamp(0, src.height - 1);
      for (var x = 0; x < src.width; x++) {
        final cellCenterX = (x ~/ cell) * cell + half;
        final sampleX = cellCenterX.floor().clamp(0, src.width - 1);
        final sample = source.getPixel(sampleX, sampleY);

        final dx = x - cellCenterX;
        final dy = y - cellCenterY;
        final dist = math.sqrt(dx * dx + dy * dy);
        // ドットの内側を1、外側を0とする（境界は滑らかに）。
        final coverage = 1.0 - _smoothstep(dotRadius - 0.75, dotRadius + 0.75, dist);

        final p = src.getPixel(x, y);
        p
          ..r = _mix(sample.r * gapDarken, sample.r, coverage)
          ..g = _mix(sample.g * gapDarken, sample.g, coverage)
          ..b = _mix(sample.b * gapDarken, sample.b, coverage);
      }
    }
    return src;
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static num _mix(num a, num b, double t) => a + (b - a) * t;
}
