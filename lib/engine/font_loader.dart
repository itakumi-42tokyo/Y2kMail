import 'package:flutter/services.dart' show rootBundle;

import 'bdf_font.dart';

// BDFフォントをアセットから読み込む（パースはIsolate内で行う）。
Future<BdfFont> loadUnifont() async {
  final text = await rootBundle.loadString('assets/fonts/unifont.bdf');
  return BdfFont.parse(text);
}

// 8ドットの美咲フォント（小さい表示用）。
Future<BdfFont> loadMisaki() async {
  final text = await rootBundle.loadString('assets/fonts/misaki_gothic.bdf');
  return BdfFont.parse(text);
}
