import 'package:flutter_test/flutter_test.dart';
import 'package:kengai/engine/bdf_font.dart';
import 'package:kengai/engine/framebuffer.dart';

// フォントが無くても検証できる、フレームバッファの基本動作のテスト。
BdfFont _emptyFont() => BdfFont(const {}, cellHeight: 16);

void main() {
  test('setPixel と getPixel が対応する', () {
    final fb = Framebuffer(_emptyFont());
    expect(fb.getPixel(10, 20), isFalse);
    fb.setPixel(10, 20, on: true);
    expect(fb.getPixel(10, 20), isTrue);
    fb.setPixel(10, 20, on: false);
    expect(fb.getPixel(10, 20), isFalse);
  });

  test('画面外への描画は無視される', () {
    final fb = Framebuffer(_emptyFont());
    fb.setPixel(-1, 0, on: true);
    fb.setPixel(Framebuffer.width, 0, on: true);
    fb.setPixel(0, Framebuffer.height, on: true);
    // 例外が出ず、範囲外は点灯しない。
    expect(fb.getPixel(0, 0), isFalse);
  });

  test('fillRect と clear が効く', () {
    final fb = Framebuffer(_emptyFont());
    fb.fillRect(2, 3, 4, 5, on: true);
    expect(fb.getPixel(2, 3), isTrue);
    expect(fb.getPixel(5, 7), isTrue);
    expect(fb.getPixel(6, 8), isFalse);
    fb.clear();
    expect(fb.getPixel(2, 3), isFalse);
  });
}
