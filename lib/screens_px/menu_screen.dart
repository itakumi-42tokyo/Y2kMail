import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/palette.dart';
import '../engine/pixel_canvas.dart';

// 見本のメニュー画面。すべてフレームバッファにドットで描く。
// （描画方式の確認用。実データとの接続はこの土台の上で順次行う）
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.font});

  final BdfFont font;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const _items = ['電話帳', '自己紹介', 'メール', '着せ替え', 'ログアウト'];

  int _selected = 0;
  int _key = 0;

  // メニュー項目の開始Y座標と行の高さ。
  static const int _itemsTop = 36;
  static const int _rowH = 16;

  void _onTap(int x, int y) {
    if (y < _itemsTop) return;
    final idx = (y - _itemsTop) ~/ _rowH;
    if (idx < 0 || idx >= _items.length) return;
    setState(() {
      _selected = idx;
      _key++;
    });
  }

  void _paint(Framebuffer fb) {
    fb.clear(Palette.bg);

    // 上部ステータス帯（電波・電池をドットで描く）。
    _drawStatusBar(fb);

    // タイトル帯（反転表示）。
    fb.fillRect(0, 18, Framebuffer.width, 14, Palette.highlight);
    fb.drawText(4, 18, 'メニュー', Palette.onHighlight);

    // メニュー項目。
    for (var i = 0; i < _items.length; i++) {
      final y = _itemsTop + i * _rowH;
      if (i == _selected) {
        // 選択中は帯を反転。
        fb.fillRect(0, y, Framebuffer.width, _rowH, Palette.highlight);
        fb.drawText(2, y, '>', Palette.onHighlight);
        fb.drawText(16, y, _items[i], Palette.onHighlight);
      } else {
        fb.drawText(16, y, _items[i], Palette.ink);
      }
    }
  }

  void _drawStatusBar(Framebuffer fb) {
    // 電波アイコン（アンテナの柱＋バー）。圏外なのでバーは少なめ。
    fb.vLine(4, 2, 12, Palette.ink);
    for (var b = 0; b < 2; b++) {
      final bx = 7 + b * 3;
      final bh = 4 + b * 3;
      fb.fillRect(bx, 14 - bh, 2, bh, Palette.ink);
    }
    // 「圏外」の文字。
    fb.drawText(18, 0, '圏外', Palette.ink);

    // 電池アイコン（右上）。
    const bx = 100;
    fb.rect(bx, 3, 16, 8, Palette.ink);
    fb.fillRect(bx + 16, 5, 2, 4, Palette.ink);
    fb.fillRect(bx + 2, 5, 10, 4, Palette.ink);

    // 区切り線。
    fb.hLine(0, 16, Framebuffer.width, Palette.line);
  }

  @override
  Widget build(BuildContext context) {
    return PixelCanvas(
      font: widget.font,
      repaintKey: _key,
      paint: _paint,
      onTapDown: _onTap,
    );
  }
}
