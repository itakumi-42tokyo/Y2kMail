import 'dart:typed_data';

import 'bdf_font.dart';

// 120x160 の仮想フレームバッファ（RGBA）。
// すべての描画はここに整数ドット単位で行う。
class Framebuffer {
  Framebuffer(this.font);

  static const int width = 120;
  static const int height = 160;

  final BdfFont font;
  final Uint8List pixels = Uint8List(width * height * 4);

  void clear(List<int> color) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        _set(x, y, color);
      }
    }
  }

  void setPixel(int x, int y, List<int> color) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    _set(x, y, color);
  }

  void _set(int x, int y, List<int> color) {
    final i = (y * width + x) * 4;
    pixels[i] = color[0];
    pixels[i + 1] = color[1];
    pixels[i + 2] = color[2];
    pixels[i + 3] = color[3];
  }

  void fillRect(int x, int y, int w, int h, List<int> color) {
    for (var yy = y; yy < y + h; yy++) {
      for (var xx = x; xx < x + w; xx++) {
        setPixel(xx, yy, color);
      }
    }
  }

  // 枠線だけ描く。
  void rect(int x, int y, int w, int h, List<int> color) {
    hLine(x, y, w, color);
    hLine(x, y + h - 1, w, color);
    vLine(x, y, h, color);
    vLine(x + w - 1, y, h, color);
  }

  void hLine(int x, int y, int len, List<int> color) {
    for (var xx = x; xx < x + len; xx++) {
      setPixel(xx, y, color);
    }
  }

  void vLine(int x, int y, int len, List<int> color) {
    for (var yy = y; yy < y + len; yy++) {
      setPixel(x, yy, color);
    }
  }

  // グラデーションの代わりに、1行おきの横縞で濃淡を表す（ディザ風）。
  void fillDither(int x, int y, int w, int h, List<int> color) {
    for (var yy = y; yy < y + h; yy++) {
      if (yy.isEven) continue;
      hLine(x, yy, w, color);
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

  // 文字列を描画し、描画後の右端X座標を返す。
  int drawText(int x, int y, String s, List<int> color) {
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
            setPixel(cx + col, y + row, color);
          }
        }
      }
      cx += g.advance;
    }
    return cx;
  }

  // 中央寄せでテキストを描く。
  void drawTextCentered(int y, String s, List<int> color) {
    final w = textWidth(s);
    drawText((width - w) ~/ 2, y, s, color);
  }
}
