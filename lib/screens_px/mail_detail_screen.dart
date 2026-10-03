import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../models/mail.dart';
import '../util/date_format.dart';
import 'pixel_text_region.dart';

// メール詳細（読み取り専用）。本文は共通部品 PixelTextRegion で表示・スクロール。
class MailDetailScreen extends StatefulWidget {
  const MailDetailScreen({
    super.key,
    required this.font,
    required this.mail,
    required this.isInbox,
  });

  final BdfFont font;
  final Mail mail;
  final bool isInbox; // 受信=From / 送信=To

  @override
  State<MailDetailScreen> createState() => _MailDetailScreenState();
}

class _MailDetailScreenState extends State<MailDetailScreen> {
  late final TextEditingController _bodyCtrl =
      TextEditingController(text: widget.mail.body ?? '');
  late final PixelTextRegion _bodyRegion = PixelTextRegion(
    controller: _bodyCtrl,
    focus: FocusNode(),
    font: widget.font,
    x: 4, y: 64, w: 112, h: 80,
    lineHeight: 16, maxLines: 5, singleLine: false,
    readOnly: true,
  );

  int _key = 0;

  void _onPan1(int x, int y) => _panStart = y;
  int _panStart = 0;
  void _onPan2(int x, int y) {
    final lines = (y - _panStart) ~/ 16;
    if (lines != 0) {
      _bodyRegion.scrollByLines(-lines);
      _panStart += lines * 16;
      setState(() => _key++);
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    fb.fillRect(0, 0, Framebuffer.width, 16, on: true);
    fb.drawText(2, 0, 'メール', on: false);

    final m = widget.mail;
    final who = widget.isInbox ? 'From:${m.partnerName}' : 'To:${m.partnerName}';
    fb.drawText(2, 18, who, on: true, clipRight: Framebuffer.width - 2);
    fb.drawText(2, 34, detailDate(m.createdAt), on: true);

    final subject = (m.subject?.trim().isNotEmpty ?? false) ? m.subject! : '(件名なし)';
    fb.drawText(2, 48, subject, on: true, clipRight: Framebuffer.width - 2);

    fb.rect(4, 64, 112, 80, on: true);
    _bodyRegion.draw(fb, caretOn: false, active: false);

    if (m.hasPhoto) fb.drawText(2, 146, 'しゃしんあり', on: true);
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LedCanvas(
      font: widget.font,
      repaintKey: _key,
      paint: _paint,
      onPanStart: _onPan1,
      onPanUpdate: _onPan2,
    );
  }
}
