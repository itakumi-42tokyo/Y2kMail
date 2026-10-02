import 'dart:isolate';

// BDFフォント1文字分のグリフ。
class Glyph {
  Glyph({
    required this.advance,
    required this.width,
    required this.rowBits,
    required this.topRow,
    required this.rows,
  });

  /// 次の文字までの横幅（ドット）。
  final int advance;

  /// 実際の絵の横幅（ドット）。
  final int width;

  /// 1行あたりのビット数（16や8。左詰め）。
  final int rowBits;

  /// 16ドットのセル内で、絵が始まる上端の行。
  final int topRow;

  /// 各行のビットパターン（左のドットが上位ビット）。
  final List<int> rows;

  /// セル座標 (col,row) にドットが立っているか。
  bool isOn(int col, int row) {
    final r = row - topRow;
    if (r < 0 || r >= rows.length) return false;
    if (col < 0 || col >= width) return false;
    final bit = (rows[r] >> (rowBits - 1 - col)) & 1;
    return bit == 1;
  }
}

// BDFフォント全体。コードポイント→グリフ。
class BdfFont {
  BdfFont(this.glyphs, {required this.cellHeight});

  final Map<int, Glyph> glyphs;

  /// セルの高さ（ドット）。
  final int cellHeight;

  Glyph? glyphFor(int codePoint) => glyphs[codePoint];

  /// アセットのBDF文字列を、別スレッド（Isolate）でパースして読み込む。
  static Future<BdfFont> parse(String bdfText) async {
    final glyphs = await Isolate.run(() => _parse(bdfText));
    return BdfFont(glyphs, cellHeight: 16);
  }

  static Map<int, Glyph> _parse(String text) {
    const fontAscent = 14; // FONTBOUNDINGBOX 16 16 0 -2 より（16-2=14）
    final glyphs = <int, Glyph>{};
    final lines = text.split('\n');

    int i = 0;
    while (i < lines.length) {
      if (!lines[i].startsWith('STARTCHAR')) {
        i++;
        continue;
      }

      int encoding = -1;
      int advance = 0;
      int bw = 0, bh = 0, bxoff = 0, byoff = 0;
      i++;
      // STARTCHAR から BITMAP までのヘッダを読む。
      while (i < lines.length && !lines[i].startsWith('BITMAP')) {
        final line = lines[i];
        if (line.startsWith('ENCODING')) {
          encoding = int.parse(line.substring(9).trim());
        } else if (line.startsWith('DWIDTH')) {
          advance = int.parse(line.substring(7).trim().split(' ')[0]);
        } else if (line.startsWith('BBX')) {
          final p = line.substring(4).trim().split(' ');
          bw = int.parse(p[0]);
          bh = int.parse(p[1]);
          bxoff = int.parse(p[2]);
          byoff = int.parse(p[3]);
        }
        i++;
      }
      i++; // BITMAP の次の行へ

      final rows = <int>[];
      int rowBits = 0;
      while (i < lines.length && !lines[i].startsWith('ENDCHAR')) {
        final hex = lines[i].trim();
        if (hex.isNotEmpty) {
          rowBits = hex.length * 4;
          rows.add(int.parse(hex, radix: 16));
        }
        i++;
      }
      i++; // ENDCHAR の次へ

      if (encoding >= 0 && rows.isNotEmpty) {
        // 絵の上端のセル行。BBXのオフセットから求める。
        final topRow = (fontAscent - byoff - bh);
        glyphs[encoding] = Glyph(
          advance: advance,
          // xoffは左右位置の微調整。簡単のため絵の幅に足し込む。
          width: bw + (bxoff > 0 ? bxoff : 0),
          rowBits: rowBits,
          topRow: topRow < 0 ? 0 : topRow,
          rows: rows,
        );
      }
    }
    return glyphs;
  }
}
