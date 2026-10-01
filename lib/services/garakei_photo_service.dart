import 'dart:isolate';
import 'dart:typed_data';

import 'garakei_photo_processor.dart';

/// 写真の低画質化は重い処理なので、メインスレッド（画面の描画を行うスレッド）
/// をブロックしないよう、Isolate（メモリを共有しない別スレッドのようなもの）で実行する。
class GarakeiPhotoService {
  static Future<Uint8List> process(
    Uint8List originalBytes, {
    int quality = 92,
    double brightness = 1.12,
    double saturation = 1.15,
    double contrast = 1.05,
    int targetWidth = 0,
    int dotsAcross = 100,
    double dotFill = 0.85,
    double gapDarken = 0.35,
    int glowBlurRadius = 0,
    double glowThreshold = 0.7,
  }) {
    return Isolate.run(
      () => GarakeiPhotoProcessor.process(
        originalBytes,
        quality: quality,
        brightness: brightness,
        saturation: saturation,
        contrast: contrast,
        targetWidth: targetWidth,
        dotsAcross: dotsAcross,
        dotFill: dotFill,
        gapDarken: gapDarken,
        glowBlurRadius: glowBlurRadius,
        glowThreshold: glowThreshold,
      ),
    );
  }
}
