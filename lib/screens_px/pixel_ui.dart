import '../engine/framebuffer.dart';

// ピクセル画面で使う共通の描画部品。すべて整数ドット単位。
class PixelUi {
  static const int fontH = 16;

  // 上部のタイトル帯（反転表示）。
  static void titleBar(Framebuffer fb, String title) {
    fb.fillRect(0, 0, Framebuffer.width, fontH, on: true);
    final w = fb.textWidth(title);
    fb.drawText((Framebuffer.width - w) ~/ 2, 0, title, on: false);
  }

  // 枠つきの入力欄。text を枠内にクリップして描く。focused のとき枠を二重にする。
  static void field(
    Framebuffer fb,
    int x,
    int y,
    int w,
    String text, {
    bool focused = false,
  }) {
    const h = fontH + 2;
    fb.rect(x, y, w, h, on: true);
    if (focused) fb.rect(x + 1, y + 1, w - 2, h - 2, on: true);
    fb.drawText(x + 3, y + 1, text, on: true, clipRight: x + w - 3);
  }

  // 枠つきのボタン。selected のとき塗りつぶして文字をくり抜く。
  static void button(
    Framebuffer fb,
    int x,
    int y,
    int w,
    String label, {
    bool selected = false,
  }) {
    const h = fontH + 2;
    if (selected) {
      fb.fillRect(x, y, w, h, on: true);
    } else {
      fb.rect(x, y, w, h, on: true);
    }
    final tw = fb.textWidth(label);
    fb.drawText(x + (w - tw) ~/ 2, y + 1, label, on: !selected,
        clipRight: x + w - 2);
  }

  // ボタン等の高さ（枠込み）。
  static const int buttonH = fontH + 2;
}
