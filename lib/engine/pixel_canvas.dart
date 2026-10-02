import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'bdf_font.dart';
import 'framebuffer.dart';

// 仮想フレームバッファ(120x160)を整数倍・補間なしで画面に表示する土台。
// [paint] でバッファに描き、タップは仮想ドット座標で [onTapDown] に渡す。
class PixelCanvas extends StatefulWidget {
  const PixelCanvas({
    super.key,
    required this.font,
    required this.paint,
    this.onTapDown,
    this.repaintKey = 0,
  });

  final BdfFont font;
  final void Function(Framebuffer fb) paint;
  final void Function(int x, int y)? onTapDown;

  /// この値が変わると再描画する。
  final int repaintKey;

  @override
  State<PixelCanvas> createState() => _PixelCanvasState();
}

class _PixelCanvasState extends State<PixelCanvas> {
  late final Framebuffer _fb = Framebuffer(widget.font);
  ui.Image? _image;
  int _lastKey = -1;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(PixelCanvas old) {
    super.didUpdateWidget(old);
    if (widget.repaintKey != _lastKey) _rebuild();
  }

  void _rebuild() {
    _lastKey = widget.repaintKey;
    widget.paint(_fb);
    ui.decodeImageFromPixels(
      _fb.pixels,
      Framebuffer.width,
      Framebuffer.height,
      ui.PixelFormat.rgba8888,
      (img) {
        if (mounted) setState(() => _image = img);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 画面に収まる最大の整数倍率を求める。
        final sx = constraints.maxWidth ~/ Framebuffer.width;
        final sy = constraints.maxHeight ~/ Framebuffer.height;
        final scale = (sx < sy ? sx : sy).clamp(1, 100);
        final dw = Framebuffer.width * scale;
        final dh = Framebuffer.height * scale;
        final offX = (constraints.maxWidth - dw) / 2;
        final offY = (constraints.maxHeight - dh) / 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final cb = widget.onTapDown;
            if (cb == null) return;
            final lx = details.localPosition.dx - offX;
            final ly = details.localPosition.dy - offY;
            if (lx < 0 || ly < 0 || lx >= dw || ly >= dh) return;
            cb(lx ~/ scale, ly ~/ scale);
          },
          child: Container(
            color: const Color(0xFF000000), // 余白は黒（端末のフチ風）
            alignment: Alignment.center,
            child: _image == null
                ? const SizedBox.shrink()
                : SizedBox(
                    width: dw.toDouble(),
                    height: dh.toDouble(),
                    child: CustomPaint(painter: _ImagePainter(_image!)),
                  ),
          ),
        );
      },
    );
  }
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size;
    // 補間なしで整数倍拡大する。
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
