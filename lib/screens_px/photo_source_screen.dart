import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import 'pixel_ui.dart';

// 写真の入手方法を選ぶ（カメラが上、ギャラリーが下）。選んだ ImageSource を返す。
class PhotoSourceScreen extends StatefulWidget {
  const PhotoSourceScreen({super.key, required this.font});

  final BdfFont font;

  @override
  State<PhotoSourceScreen> createState() => _PhotoSourceScreenState();
}

class _PhotoSourceScreenState extends State<PhotoSourceScreen> {
  static const int _cameraY = 28;
  static const int _galleryY = 50;

  void _onTap(int x, int y) {
    if (y >= _cameraY && y < _cameraY + PixelUi.buttonH) {
      Navigator.of(context).pop(ImageSource.camera);
    } else if (y >= _galleryY && y < _galleryY + PixelUi.buttonH) {
      Navigator.of(context).pop(ImageSource.gallery);
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'しゃしん');
    PixelUi.button(fb, 4, _cameraY, 112, 'カメラでとる');
    PixelUi.button(fb, 4, _galleryY, 112, 'しゃしんをえらぶ');
  }

  @override
  Widget build(BuildContext context) {
    return LedCanvas(
      font: widget.font,
      paint: _paint,
      onTapDown: _onTap,
    );
  }
}
