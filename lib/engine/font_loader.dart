import 'package:flutter/services.dart' show rootBundle;

import 'bdf_font.dart';

// BDFフォントをアセットから読み込む（パースはIsolate内で行う）。
Future<BdfFont> loadUnifont() async {
  final text = await rootBundle.loadString('assets/fonts/unifont.bdf');
  return BdfFont.parse(text);
}
