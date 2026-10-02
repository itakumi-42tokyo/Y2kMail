import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';

// 見本のメニュー画面。すべてフレームバッファにドットで描く。
// （描画方式の確認用。実データとの接続はこの土台の上で順次行う）
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.font, this.onLogout});

  final BdfFont font;
  final VoidCallback? onLogout;

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
    // いまはログアウトのみ実動作（他画面は順次移植）。
    if (_items[idx] == 'ログアウト') widget.onLogout?.call();
  }

  void _paint(Framebuffer fb) {
    fb.clear();

    // 上部ステータス帯（電波・電池をドットで描く）。
    _drawStatusBar(fb);

    // タイトル帯（点灯で塗り、文字をくり抜いて反転表示）。
    fb.fillRect(0, 18, Framebuffer.width, 14, on: true);
    fb.drawText(4, 18, 'メニュー', on: false);

    // メニュー項目。
    for (var i = 0; i < _items.length; i++) {
      final y = _itemsTop + i * _rowH;
      if (i == _selected) {
        // 選択中は帯を点灯させ、文字をくり抜く。
        fb.fillRect(0, y, Framebuffer.width, _rowH, on: true);
        fb.drawText(2, y, '>', on: false);
        fb.drawText(16, y, _items[i], on: false);
      } else {
        fb.drawText(16, y, _items[i], on: true);
      }
    }
  }

  void _drawStatusBar(Framebuffer fb) {
    // 電波アイコン（アンテナの柱＋バー）。圏外なのでバーは少なめ。
    fb.vLine(4, 2, 12);
    for (var b = 0; b < 2; b++) {
      final bx = 7 + b * 3;
      final bh = 4 + b * 3;
      fb.fillRect(bx, 14 - bh, 2, bh);
    }
    // 「圏外」の文字。
    fb.drawText(18, 0, '圏外');

    // 電池アイコン（右上）。
    const bx = 100;
    fb.rect(bx, 3, 16, 8);
    fb.fillRect(bx + 16, 5, 2, 4);
    fb.fillRect(bx + 2, 5, 10, 4);

    // 区切り線。
    fb.hLine(0, 16, Framebuffer.width);
  }

  @override
  Widget build(BuildContext context) {
    return LedCanvas(
      font: widget.font,
      repaintKey: _key,
      paint: _paint,
      onTapDown: _onTap,
    );
  }
}
