import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../engine/pixel_route.dart';
import '../repositories/friend_repository.dart';
import '../repositories/mail_repository.dart';
import 'compose_mail_screen.dart';

// メールメニュー: 新規作成 / 受信BOX / 送信BOX。
// いまは新規作成のみ接続（受信/送信BOXは次に移植）。
class MailMenuScreen extends StatefulWidget {
  const MailMenuScreen({
    super.key,
    required this.font,
    required this.friendRepository,
    required this.mailRepository,
  });

  final BdfFont font;
  final FriendRepository friendRepository;
  final MailRepository mailRepository;

  @override
  State<MailMenuScreen> createState() => _MailMenuScreenState();
}

class _MailMenuScreenState extends State<MailMenuScreen> {
  static const items = ['しんきさくせい', 'じゅしんBOX', 'そうしんBOX'];

  int _selected = 0;
  String _message = '';
  int _key = 0;

  static const int _itemsTop = 24;
  static const int _rowH = 16;

  void _onTap(int x, int y) {
    if (y < _itemsTop) return;
    final idx = (y - _itemsTop) ~/ _rowH;
    if (idx < 0 || idx >= items.length) return;
    if (idx != _selected) {
      setState(() {
        _selected = idx;
        _key++;
      });
      return;
    }
    switch (items[idx]) {
      case 'しんきさくせい':
        _compose();
      default:
        setState(() {
          _message = '準備中';
          _key++;
        });
    }
  }

  Future<void> _compose() async {
    await Navigator.of(context).push(pixelRoute((_) => ComposeMailScreen(
          font: widget.font,
          friendRepository: widget.friendRepository,
          mailRepository: widget.mailRepository,
        )));
    if (mounted) {
      setState(() {
        _message = '';
        _key++;
      });
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    fb.fillRect(0, 0, Framebuffer.width, 16, on: true);
    fb.drawText(4, 0, 'メール', on: false);

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
    if (_message.isNotEmpty) fb.drawTextCentered(100, _message, on: true);
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
