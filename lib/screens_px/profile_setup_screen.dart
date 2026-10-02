import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../repositories/profile_repository.dart';
import 'pixel_ui.dart';

// 初回ログイン時の表示名登録（ピクセル描画・IME自前描画）。
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.font,
    required this.profileRepository,
    required this.onCreated,
  });

  final BdfFont font;
  final ProfileRepository profileRepository;
  final VoidCallback onCreated;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();

  bool _loading = false;
  String? _error;
  int _key = 0;

  static const int _fieldY = 54;
  static const int _okY = 82;

  @override
  void initState() {
    super.initState();
    _name.addListener(_bump);
    _focus.addListener(_bump);
  }

  void _bump() => setState(() => _key++);

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'なまえをいれてね';
        _key++;
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _key++;
    });
    try {
      await widget.profileRepository.createProfile(name);
      widget.onCreated();
    } catch (e) {
      setState(() {
        _error = 'とうろく失敗';
        _loading = false;
        _key++;
      });
    }
  }

  bool _hit(int y, int top) => y >= top && y < top + PixelUi.buttonH;

  void _onTap(int x, int y) {
    if (_loading) return;
    if (_hit(y, _fieldY)) {
      _focus.requestFocus();
    } else if (_hit(y, _okY)) {
      _create();
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'なまえ');
    fb.drawText(4, 22, 'ひょうじめい', on: true);
    fb.drawText(4, 38, 'あとでかえられます', on: true);
    PixelUi.field(fb, 4, _fieldY, 112, _name.text, focused: _focus.hasFocus);
    PixelUi.button(fb, 4, _okY, 112, 'けってい');
    if (_loading) fb.drawTextCentered(110, 'とうろく中…', on: true);
    if (_error != null) fb.drawTextCentered(110, _error!, on: true);
  }

  @override
  void dispose() {
    _name.dispose();
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
              controller: _name,
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
