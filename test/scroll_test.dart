import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kengai/engine/bdf_font.dart';
import 'package:kengai/screens_px/pixel_text_region.dart';

BdfFont _font() => BdfFont(const {}, cellHeight: 16);

PixelTextRegion _region(String text) {
  final c = TextEditingController(text: text);
  return PixelTextRegion(
    controller: c,
    focus: FocusNode(),
    font: _font(),
    x: 0, y: 0, w: 120, h: 32,
    lineHeight: 16, maxLines: 2, singleLine: false,
  );
}

void main() {
  // 5行のテキスト（1行1文字＋改行）。
  const text = 'a\nb\nc\nd\ne';

  test('カーソルが下にあると先頭行が追従する', () {
    final r = _region(text);
    // 'e' は5行目(index0起点で line4)。末尾にカーソル。
    r.controller.selection = const TextSelection.collapsed(offset: 8);
    r.scrollToCaret();
    // maxLines=2 なので firstLine は line4 が見える最小値 = 3。
    expect(r.firstLine, 3);
  });

  test('カーソルが上に戻ると先頭行も戻る', () {
    final r = _region(text);
    r.controller.selection = const TextSelection.collapsed(offset: 8);
    r.scrollToCaret();
    expect(r.firstLine, 3);
    // 先頭へ。
    r.controller.selection = const TextSelection.collapsed(offset: 0);
    r.scrollToCaret();
    expect(r.firstLine, 0);
  });

  test('scrollByLines は範囲でクランプされる', () {
    final r = _region(text); // 5行, maxLines2 → 最大firstLine=3
    r.scrollByLines(100);
    expect(r.firstLine, 3);
    r.scrollByLines(-100);
    expect(r.firstLine, 0);
    r.scrollByLines(2);
    expect(r.firstLine, 2);
  });

  test('行数が表示行以下ならスクロールしない', () {
    final r = _region('a\nb'); // 2行, maxLines2
    r.scrollByLines(5);
    expect(r.firstLine, 0);
  });
}
