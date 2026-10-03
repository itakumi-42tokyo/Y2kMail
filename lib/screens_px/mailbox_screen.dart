import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../engine/pixel_route.dart';
import '../models/mail.dart';
import '../repositories/mail_repository.dart';
import '../util/date_format.dart';
import 'mail_detail_screen.dart';

// 受信BOX / 送信BOX の一覧（1件2行・3件/ページのページ送り）。
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({
    super.key,
    required this.font,
    required this.mailRepository,
    required this.isInbox,
  });

  final BdfFont font;
  final MailRepository mailRepository;
  final bool isInbox;

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  static const int _pageSize = 3;
  static const int _itemsTop = 18;
  static const int _itemH = 32;
  static const int _pagerY = 130;

  List<Mail> _items = [];
  int _page = 0;
  int _totalPages = 1;
  bool _loading = true;
  int _key = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _key++;
    });
    try {
      final total = widget.isInbox
          ? await widget.mailRepository.countInbox()
          : await widget.mailRepository.countOutbox();
      final pages = total <= 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
      if (_page >= pages) _page = pages - 1;
      final items = widget.isInbox
          ? await widget.mailRepository
              .fetchInbox(page: _page, pageSize: _pageSize)
          : await widget.mailRepository
              .fetchOutbox(page: _page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items = items;
        _totalPages = pages;
        _loading = false;
        _key++;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _key++;
        });
      }
    }
  }

  void _onTap(int x, int y) {
    // ページ送り。
    if (y >= _pagerY) {
      if (x < 40 && _page > 0) {
        _page--;
        _load();
      } else if (x > 80 && _page < _totalPages - 1) {
        _page++;
        _load();
      }
      return;
    }
    // 項目タップ→詳細。
    if (y >= _itemsTop) {
      final idx = (y - _itemsTop) ~/ _itemH;
      if (idx >= 0 && idx < _items.length) {
        Navigator.of(context).push(pixelRoute((_) => MailDetailScreen(
              font: widget.font,
              mail: _items[idx],
              isInbox: widget.isInbox,
            )));
      }
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    fb.fillRect(0, 0, Framebuffer.width, 16, on: true);
    fb.drawText(2, 0, widget.isInbox ? 'じゅしんBOX' : 'そうしんBOX', on: false);

    if (_loading) {
      fb.drawText(4, _itemsTop, 'よみこみ中…', on: true);
      return;
    }
    if (_items.isEmpty) {
      fb.drawText(4, _itemsTop, 'メールなし', on: true);
    }

    for (var i = 0; i < _items.length; i++) {
      final m = _items[i];
      final top = _itemsTop + i * _itemH;

      // 1行目: (受信は未開封アイコン枠)＋相手名 … 右端に日時。
      final date = listDate(m.createdAt);
      final dateW = fb.textWidth(date);
      final dateX = Framebuffer.width - 2 - dateW;
      fb.drawText(dateX, top, date, on: true);

      // 未開封アイコン枠は常に確保して名前位置を揃える（受信のみアイコンを出す予定）。
      const nameX = 12;
      fb.drawText(nameX, top, m.partnerName,
          on: true, clipRight: dateX - 2);

      // 2行目: 件名（空なら本文冒頭）。
      fb.drawText(4, top + 16, m.listTitle,
          on: true, clipRight: Framebuffer.width - 2);

      // 区切り線。
      fb.hLine(0, top + _itemH - 1, Framebuffer.width, on: true);
    }

    // ページャ: ◀ p/N ▶
    if (_page > 0) fb.drawText(4, _pagerY, '◀', on: true);
    final label = '${_page + 1}/$_totalPages';
    fb.drawTextCentered(_pagerY, label, on: true);
    if (_page < _totalPages - 1) {
      final w = fb.textWidth('▶');
      fb.drawText(Framebuffer.width - 4 - w, _pagerY, '▶', on: true);
    }
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
