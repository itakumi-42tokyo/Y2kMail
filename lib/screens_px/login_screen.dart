import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../repositories/auth_repository.dart';
import 'pixel_ui.dart';

// ログイン画面（ピクセル描画）。
// 文字入力は画面外のEditableTextでIME（変換中も含む）を受け取り、自前で描く。
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.font,
    required this.authRepository,
  });

  final BdfFont font;
  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _focus = FocusNode();

  bool _sent = false;
  bool _loading = false;
  String? _error;
  int _key = 0;

  // 各領域のY座標（タップ判定と描画で共有）。
  static const int _fieldY = 40;
  static const int _sendY = 66;
  static const int _googleY = 104;

  @override
  void initState() {
    super.initState();
    _email.addListener(_bump);
    _focus.addListener(_bump);
  }

  void _bump() => setState(() => _key++);

  Future<void> _sendLink() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _key++;
    });
    try {
      await widget.authRepository.sendEmailOtp(_email.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = 'そうしん失敗');
    } finally {
      setState(() {
        _loading = false;
        _key++;
      });
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
      _key++;
    });
    try {
      await widget.authRepository.signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'ログイン失敗');
    } finally {
      setState(() {
        _loading = false;
        _key++;
      });
    }
  }

  bool _hit(int y, int top) => y >= top && y < top + PixelUi.buttonH;

  void _onTap(int x, int y) {
    if (_loading) return;
    if (_sent) return;
    if (_hit(y, _fieldY)) {
      _focus.requestFocus();
    } else if (_hit(y, _sendY)) {
      _sendLink();
    } else if (_hit(y, _googleY)) {
      _google();
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'ログイン');

    if (_sent) {
      fb.drawText(4, 40, 'メールを', on: true);
      fb.drawText(4, 58, 'おくりました', on: true);
      fb.drawText(4, 84, 'リンクを', on: true);
      fb.drawText(4, 102, 'タップしてね', on: true);
      return;
    }

    fb.drawText(4, 22, 'メールアドレス', on: true);
    PixelUi.field(fb, 4, _fieldY, 112, _email.text, focused: _focus.hasFocus);
    PixelUi.button(fb, 4, _sendY, 112, 'リンクをおくる');
    fb.drawTextCentered(88, 'または', on: true);
    PixelUi.button(fb, 4, _googleY, 112, 'Googleでログイン');

    if (_loading) fb.drawTextCentered(130, 'そうしん中…', on: true);
    if (_error != null) fb.drawTextCentered(130, _error!, on: true);
  }

  @override
  void dispose() {
    _email.dispose();
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
        // IME受け取り用の、見えない入力欄（画面外・不透明度0）。
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: EditableText(
              controller: _email,
              focusNode: _focus,
              keyboardType: TextInputType.emailAddress,
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
