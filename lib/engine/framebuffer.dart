import 'dart:typed_data';

import 'bdf_font.dart';

// 120x160 の仮想フレームバッファ。
// 各ドットはパレット番号を持つ（0=消灯/地, 1=点灯 など）。
// 番号→色の対応や形は、見せ方の層（PanelRenderer）が決める。
// フォントやこのバッファの中身は、パネルの見せ方に依存しない。
class Framebuffer {
  Framebuffer(this.font);

  static const int width = 120;
  static const int height = 160;

  final BdfFont font;

  // 1ドット1バイトのパレット番号。
  final Uint8List pixels = Uint8List(width * height);

  void clear({bool on = false}) {
    pixels.fillRange(0, pixels.length, on ? 1 : 0);
  }

  void setPixel(int x, int y, {bool on = true}) {
    setIndex(x, y, on ? 1 : 0);
  }

  void setIndex(int x, int y, int paletteIndex) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    pixels[y * width + x] = paletteIndex;
  }

  bool getPixel(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return false;
    return pixels[y * width + x] != 0;
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
  // clipRight を与えると、その X 座標を超える点は描かない（入力欄の枠内に収める）。
  int drawText(int x, int y, String s, {bool on = true, int? clipRight}) {
    var cx = x;
    for (final rune in s.runes) {
      final g = font.glyphFor(rune);
      if (g == null) {
        cx += 8;
        continue;
      }
      for (var row = 0; row < font.cellHeight; row++) {
        for (var col = 0; col < g.width; col++) {
          if (!g.isOn(col, row)) continue;
          final px = cx + col;
          if (clipRight != null && px > clipRight) continue;
          setPixel(px, y + row, on: on);
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

  // 折り返しながら複数行で描く。改行(\n)でも折り返す。描いた行数を返す。
  int drawTextWrapped(
    int x,
    int y,
    int maxWidth,
    int lineH,
    int maxLines,
    String s, {
    bool on = true,
  }) {
    var line = 0;
    for (final paragraph in s.split('\n')) {
      var cur = '';
      for (final rune in paragraph.runes) {
        final ch = String.fromCharCode(rune);
        if (textWidth(cur + ch) > maxWidth && cur.isNotEmpty) {
          if (line >= maxLines) return line;
          drawText(x, y + line * lineH, cur, on: on);
          line++;
          cur = ch;
        } else {
          cur += ch;
        }
      }
      if (line >= maxLines) return line;
      drawText(x, y + line * lineH, cur, on: on);
      line++;
    }
    return line;
  }
}
