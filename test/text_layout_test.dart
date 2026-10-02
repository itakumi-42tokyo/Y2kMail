import 'package:flutter_test/flutter_test.dart';
import 'package:kengai/engine/bdf_font.dart';
import 'package:kengai/engine/text_layout.dart';

// グリフ無しのフォント。全文字の送り幅は既定の8ドットになる。
BdfFont _font() => BdfFont(const {}, cellHeight: 16);

void main() {
  const lineH = 16;

  test('幅で折り返す（1行5文字）', () {
    // 8ドット文字×8、最大幅40 → 5文字で折り返し。
    final l = TextLayout.build('abcdefgh', _font(), 40, lineH);
    expect(l.lineCount, 2);
    expect(l.lines[0].start, 0);
    expect(l.lines[0].charCount, 5);
    expect(l.lines[1].start, 5);
    expect(l.lines[1].charCount, 3);

    // ソフト折り返しの境界(index5)は次の行の先頭に置く。
    expect(l.caretPos(5), (1, 0));
    // 末尾(index8)は最終行の末尾。
    expect(l.caretPos(8), (1, 24));
  });

  test('空行と改行直後', () {
    final l = TextLayout.build('a\n\nb', _font(), 100, lineH);
    expect(l.lineCount, 3);
    expect(l.lines[1].charCount, 0); // 空行

    expect(l.caretPos(1), (0, 8)); // 'a'の直後（1つ目の改行の位置）
    expect(l.caretPos(2), (1, 0)); // 空行（2つの改行の間）
    expect(l.caretPos(3), (2, 0)); // 'b'の直前

    // 空行をタップ → index2
    expect(l.indexAt(0, lineH * 1), 2);
  });

  test('末尾の改行', () {
    final l = TextLayout.build('ab\n', _font(), 100, lineH);
    expect(l.lineCount, 2);
    expect(l.lines[1].charCount, 0);
    expect(l.caretPos(2), (0, 16)); // 'ab'の直後（改行の位置）
    expect(l.caretPos(3), (1, 0)); // 改行の後ろ（空の最終行）
  });

  test('タップ座標から文字インデックス', () {
    final l = TextLayout.build('abcde', _font(), 100, lineH);
    expect(l.indexAt(0, 0), 0);
    expect(l.indexAt(8, 0), 1); // 'a'と'b'の境界
    expect(l.indexAt(40, 0), 5); // 末尾
    expect(l.indexAt(100, 0), 5); // 右にはみ出しても末尾でクランプ
  });

  test('選択範囲の矩形', () {
    final l = TextLayout.build('abcde', _font(), 100, lineH);
    final rects = l.selectionRects(1, 3); // 'bc'
    expect(rects.length, 1);
    expect(rects[0], (0, 8, 24));
  });
}
