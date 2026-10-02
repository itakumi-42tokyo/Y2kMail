// 使ってよい色はここに定義したものだけ。
// それぞれ RGBA のバイト列（長さ4, 0〜255）。
class Palette {
  // モノクロ液晶ふう。文字は黒、背景は灰色。
  static const List<int> bg = [0xB4, 0xB6, 0xB0, 0xFF]; // 灰色の下地
  static const List<int> ink = [0x11, 0x11, 0x11, 0xFF]; // ほぼ黒
  static const List<int> panel = [0xC6, 0xC8, 0xC2, 0xFF]; // 一段明るい面
  static const List<int> line = [0x6E, 0x70, 0x6A, 0xFF]; // 枠線
  static const List<int> highlight = [0x30, 0x30, 0x30, 0xFF]; // 選択中の帯
  static const List<int> onHighlight = [0xC6, 0xC8, 0xC2, 0xFF]; // 選択中の文字
}
