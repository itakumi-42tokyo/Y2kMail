import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import 'pixel_ui.dart';

// 開発用: トークンを手入力して返す（カメラを使わず1台で交換テストするため）。
class ManualTokenScreen extends StatefulWidget {
  const ManualTokenScreen({super.key, required this.font});

  final BdfFont font;

  @override
  State<ManualTokenScreen> createState() => _ManualTokenScreenState();
}

class _ManualTokenScreenState extends State<ManualTokenScreen> {
  final _token = TextEditingController();
  final _focus = FocusNode();
  int _key = 0;

  static const int _fieldY = 40;
  static const int _okY = 66;

  @override
  void initState() {
    super.initState();
    _token.addListener(_bump);
    _focus.addListener(_bump);
  }

  void _bump() => setState(() => _key++);

  bool _hit(int y, int top) => y >= top && y < top + PixelUi.buttonH;

  void _onTap(int x, int y) {
    if (_hit(y, _fieldY)) {
      _focus.requestFocus();
    } else if (_hit(y, _okY)) {
      Navigator.of(context).pop(_token.text.trim());
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'トークン手入力');
    fb.drawText(4, 22, 'トークンをはりつけ', on: true);
    PixelUi.field(fb, 4, _fieldY, 112, _token.text, focused: _focus.hasFocus);
    PixelUi.button(fb, 4, _okY, 112, 'ついか');
  }

  @override
  void dispose() {
    _token.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LedCanvas(
          font: widget.font,
          repaintKey: _key,
          paint: _paint,
          onTapDown: _onTap,
        ),
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: EditableText(
              controller: _token,
              focusNode: _focus,
              style: const TextStyle(fontSize: 1, color: Color(0xFF000000)),
              cursorColor: const Color(0xFF000000),
              backgroundCursorColor: const Color(0xFF000000),
            ),
          ),
        ),
      ],
    );
  }
}
