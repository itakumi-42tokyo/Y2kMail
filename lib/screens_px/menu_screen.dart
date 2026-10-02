import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../repositories/profile_repository.dart';

// メイン画面。表示名を出し、項目を選んで決定すると onActivate を呼ぶ。
// 選択中の項目をもう一度タップすると「決定」になる（カーソル移動→決定）。
class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.font,
    required this.profileRepository,
    required this.onActivate,
  });

  final BdfFont font;
  final ProfileRepository profileRepository;
  final void Function(String item) onActivate;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const items = ['電話帳', '自己紹介', '着せ替え', 'ログアウト'];

  int _selected = 0;
  int _key = 0;
  String _name = '';

  static const int _itemsTop = 40;
  static const int _rowH = 16;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final name = await widget.profileRepository.fetchDisplayName();
      if (mounted) {
        setState(() {
          _name = name;
          _key++;
        });
      }
    } catch (_) {}
  }

  void _onTap(int x, int y) {
    if (y < _itemsTop) return;
    final idx = (y - _itemsTop) ~/ _rowH;
    if (idx < 0 || idx >= items.length) return;
    if (idx == _selected) {
      widget.onActivate(items[idx]); // 2回目のタップで決定
    } else {
      setState(() {
        _selected = idx;
        _key++;
      });
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    _drawStatusBar(fb);

    // タイトル帯（表示名）。
    fb.fillRect(0, 18, Framebuffer.width, _rowH, on: true);
    final title = _name.isEmpty ? 'メニュー' : _name;
    fb.drawText(4, 18, title, on: false, clipRight: Framebuffer.width - 4);

    for (var i = 0; i < items.length; i++) {
      final y = _itemsTop + i * _rowH;
      if (i == _selected) {
        fb.fillRect(0, y, Framebuffer.width, _rowH, on: true);
        fb.drawText(2, y, '>', on: false);
        fb.drawText(16, y, items[i], on: false);
      } else {
        fb.drawText(16, y, items[i], on: true);
      }
    }
  }

  void _drawStatusBar(Framebuffer fb) {
    fb.vLine(4, 2, 12);
    for (var b = 0; b < 2; b++) {
      final bx = 7 + b * 3;
      final bh = 4 + b * 3;
      fb.fillRect(bx, 14 - bh, 2, bh);
    }
    fb.drawText(18, 0, '圏外');
    const bx = 100;
    fb.rect(bx, 3, 16, 8);
    fb.fillRect(bx + 16, 5, 2, 4);
    fb.fillRect(bx + 2, 5, 10, 4);
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
