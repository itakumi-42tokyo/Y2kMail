import 'dart:typed_data';

import 'bdf_font.dart';

// 120x160 の仮想フレームバッファ。
// 各ドットは明るさ(0-255)を持つ。色や形は描画時（PanelRenderer）が決める。
// フォントやこのバッファの中身は、パネルの見せ方に依存しない。
class Framebuffer {
  Framebuffer(this.font);

  static const int width = 120;
  static const int height = 160;

  final BdfFont font;

  // 1ドット1バイトの明るさ（0=消灯 〜 255=最大）。
  final Uint8List levels = Uint8List(width * height);

  void clear({bool on = false}) {
    levels.fillRange(0, levels.length, on ? 255 : 0);
  }

  void setPixel(int x, int y, {bool on = true}) {
    setBrightness(x, y, on ? 255 : 0);
  }

  void setBrightness(int x, int y, int level) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    levels[y * width + x] = level.clamp(0, 255);
  }

  bool getPixel(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return false;
    return levels[y * width + x] > 0;
  }

  void fillRect(int x, int y, int w, int h, {bool on = true}) {
    for (var yy = y; yy < y + h; yy++) {
      for (var xx = x; xx < x + w; xx++) {
        setPixel(xx, yy, on: on);
      }
    }
  }

  void rect(int x, int y, int w, int h, {bool on = true}) {
    hLine(x, y, w, on: on);
    hLine(x, y + h - 1, w, on: on);
    vLine(x, y, h, on: on);
    vLine(x + w - 1, y, h, on: on);
  }

  void hLine(int x, int y, int len, {bool on = true}) {
    for (var xx = x; xx < x + len; xx++) {
      setPixel(xx, y, on: on);
    }
  }

  void vLine(int x, int y, int len, {bool on = true}) {
    for (var yy = y; yy < y + len; yy++) {
      setPixel(x, yy, on: on);
    }
  }

  int textWidth(String s) {
    var total = 0;
    for (final rune in s.runes) {
      final g = font.glyphFor(rune);
      total += g?.advance ?? 8;
    }
    return total;
  }

  // 文字列を描く。on=false にすると、点灯部をくり抜く（反転表示に使う）。
  int drawText(int x, int y, String s, {bool on = true}) {
    var cx = x;
    for (final rune in s.runes) {
      final g = font.glyphFor(rune);
      if (g == null) {
        cx += 8;
        continue;
      }
      for (var row = 0; row < font.cellHeight; row++) {
        for (var col = 0; col < g.width; col++) {
          if (g.isOn(col, row)) {
            setPixel(cx + col, y + row, on: on);
          }
        }
      }
      cx += g.advance;
    }
    return cx;
  }

  void drawTextCentered(int y, String s, {bool on = true}) {
    final w = textWidth(s);
    drawText((width - w) ~/ 2, y, s, on: on);
  }
}
