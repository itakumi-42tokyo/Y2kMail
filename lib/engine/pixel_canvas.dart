import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'bdf_font.dart';
import 'framebuffer.dart';
import 'panel_renderer.dart';

// 仮想フレームバッファ(120x160)を、差し替え可能な PanelRenderer で表示する。
// [paint] でバッファにパレット番号を書き、タップは仮想ドット座標で [onTapDown] に返す。
class LedCanvas extends StatefulWidget {
  const LedCanvas({
    super.key,
    required this.font,
    required this.paint,
    this.onTapDown,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onPanStart,
    this.onPanUpdate,
    this.repaintKey = 0,
    this.renderer,
  });

  final BdfFont font;
  final void Function(Framebuffer fb) paint;
  final void Function(int x, int y)? onTapDown;
  final void Function(int x, int y)? onLongPressStart;
  final void Function(int x, int y)? onLongPressMoveUpdate;
  final void Function(int x, int y)? onPanStart;
  final void Function(int x, int y)? onPanUpdate;
  final int repaintKey;

  /// 表示パネル。省略時は丸型電球。
  final PanelRenderer? renderer;

  @override
  State<LedCanvas> createState() => _LedCanvasState();
}

class _LedCanvasState extends State<LedCanvas> {
  late final Framebuffer _fb = Framebuffer(widget.font);
  late final PanelRenderer _renderer = widget.renderer ?? BulbPanelRenderer();

  int _cellPx = 0;
  double _offX = 0, _offY = 0;
  List<RSTransform>? _transforms;
  int _lastKey = -1;
  int _ready = 0; // スプライト準備が整うたびに増やして再描画を促す

  void _ensurePainted() {
    if (widget.repaintKey != _lastKey) {
      _lastKey = widget.repaintKey;
      widget.paint(_fb);
    }
  }

  void _updateGeometry(BoxConstraints constraints) {
    final sx = constraints.maxWidth ~/ Framebuffer.width;
    final sy = constraints.maxHeight ~/ Framebuffer.height;
    final cell = (sx < sy ? sx : sy).clamp(1, 100);
    final dw = Framebuffer.width * cell;
    final dh = Framebuffer.height * cell;
    _offX = (constraints.maxWidth - dw) / 2;
    _offY = (constraints.maxHeight - dh) / 2;

    if (cell != _cellPx) {
      _cellPx = cell;
      // 高解像度スプライト(spriteSize)を、1セル(cell)に縮小して中央へ置く。
      final spr = _renderer.spriteSize;
      final s = cell / spr;
      final half = spr / 2;
      final tf = <RSTransform>[];
      for (var y = 0; y < Framebuffer.height; y++) {
        for (var x = 0; x < Framebuffer.width; x++) {
          tf.add(RSTransform.fromComponents(
            rotation: 0,
            scale: s,
            anchorX: half,
            anchorY: half,
            translateX: _offX + x * cell + cell / 2,
            translateY: _offY + y * cell + cell / 2,
          ));
        }
      }
      _transforms = tf;
      _renderer.prepare().then((_) {
        if (mounted) setState(() => _ready++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensurePainted();
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateGeometry(constraints);
        void dispatch(void Function(int, int)? cb, Offset local) {
          if (cb == null || _cellPx == 0) return;
          final lx = local.dx - _offX;
          final ly = local.dy - _offY;
          if (lx < 0 || ly < 0) return;
          final vx = lx ~/ _cellPx;
          final vy = ly ~/ _cellPx;
          if (vx >= Framebuffer.width || vy >= Framebuffer.height) return;
          cb(vx, vy);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => dispatch(widget.onTapDown, d.localPosition),
          onLongPressStart: (d) =>
              dispatch(widget.onLongPressStart, d.localPosition),
          onLongPressMoveUpdate: (d) =>
              dispatch(widget.onLongPressMoveUpdate, d.localPosition),
          onPanStart: (d) => dispatch(widget.onPanStart, d.localPosition),
          onPanUpdate: (d) => dispatch(widget.onPanUpdate, d.localPosition),
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _PanelPainter(
              renderer: _renderer,
              transforms: _transforms,
              pixels: _fb.pixels,
              cell: _cellPx,
              repaint: widget.repaintKey ^ (_ready << 20),
            ),
          ),
        );
      },
    );
  }
}

class _PanelPainter extends CustomPainter {
  _PanelPainter({
    required this.renderer,
    required this.transforms,
    required this.pixels,
    required this.cell,
    required this.repaint,
  });

  final PanelRenderer renderer;
  final List<RSTransform>? transforms;
  final Uint8List pixels;
  final int cell;
  final int repaint;

  @override
  void paint(Canvas canvas, Size size) {
    final tf = transforms;
    if (tf == null || !renderer.ready) {
      canvas.drawColor(renderer.background, BlendMode.src);
      return;
    }
    renderer.paintPanel(canvas, tf, pixels);
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.repaint != repaint || old.cell != cell;
}
