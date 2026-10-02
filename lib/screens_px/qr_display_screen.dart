import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../repositories/friend_repository.dart';
import 'pixel_ui.dart';

// 自分の交換用QRを、フレームバッファにドットで描いて表示する。
class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({
    super.key,
    required this.font,
    required this.friendRepository,
  });

  final BdfFont font;
  final FriendRepository friendRepository;

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  String? _token;
  bool _failed = false;
  bool _copied = false;
  int _key = 0;

  // 開発用「コピー」ボタンのY座標。
  static const int _copyY = 118;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  Future<void> _issue() async {
    try {
      final token = await widget.friendRepository.issueExchangeToken();
      if (mounted) {
        setState(() {
          _token = token;
          _key++;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _key++;
        });
      }
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, '赤外線そうしん');

    if (_failed) {
      fb.drawTextCentered(60, 'はっこう失敗', on: true);
      return;
    }
    final token = _token;
    if (token == null) {
      fb.drawTextCentered(60, 'はっこう中…', on: true);
      return;
    }

    _drawQr(fb, token);
    // 開発用: トークンをクリップボードへコピーするボタン。
    PixelUi.button(fb, 4, _copyY, 112, _copied ? 'コピーしました' : 'トークンをコピー');
    fb.drawTextCentered(140, 'よみとってもらってね', on: true);
  }

  Future<void> _onTap(int x, int y) async {
    final token = _token;
    if (token == null) return;
    if (y >= _copyY && y < _copyY + PixelUi.buttonH) {
      await Clipboard.setData(ClipboardData(text: token));
      if (mounted) {
        setState(() {
          _copied = true;
          _key++;
        });
      }
    }
  }

  void _drawQr(Framebuffer fb, String data) {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    final img = QrImage(qr);
    final n = img.moduleCount;

    // 画面幅に収まる整数倍率を求める（左右に余白2モジュール）。
    const avail = 116;
    final scale = (avail ~/ (n + 2)).clamp(1, 8);
    final size = n * scale;
    final ox = (Framebuffer.width - size) ~/ 2;
    const oy = 24;

    // 背景（QR部分）は消灯のまま。暗モジュールだけ点灯させる。
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (img.isDark(r, c)) {
          fb.fillRect(ox + c * scale, oy + r * scale, scale, scale, on: true);
        }
      }
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
