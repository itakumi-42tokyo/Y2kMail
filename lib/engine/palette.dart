import 'dart:ui' show Color;

// 使ってよい色はここに定義したものだけ。
// 現行パネル（丸型電球 LED）の配色。着せ替えはこの値の差し替えで行う。
class Palette {
  // 背景（黒）。
  static const Color background = Color(0xFF000000);

  // 消灯している電球（直径セル85%の単色円）。
  static const Color bulbOff = Color(0xFF3A3A3A);

  // 点灯している電球の放射状グラデーション（中心→60%→縁）。
  static const Color litCenter = Color(0xFFFFF4D6);
  static const Color litMid = Color(0xFFFFB04A);
  static const Color litEdge = Color(0xFF8A4A10);

  // 外側のにじむ光（半径1.4倍・不透明度20%程度）。
  static const Color litGlow = Color(0x33FFB04A);
}
