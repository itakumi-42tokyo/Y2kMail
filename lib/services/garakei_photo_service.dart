import 'dart:isolate';
import 'dart:typed_data';

import 'garakei_photo_processor.dart';

/// 写真の低画質化は重い処理なので、メインスレッド（画面の描画を行うスレッド）
/// をブロックしないよう、Isolate（メモリを共有しない別スレッドのようなもの）で実行する。
class GarakeiPhotoService {
  static Future<Uint8List> process(Uint8List originalBytes, {int quality = 90}) {
    return Isolate.run(
      () => GarakeiPhotoProcessor.process(originalBytes, quality: quality),
    );
  }
}
