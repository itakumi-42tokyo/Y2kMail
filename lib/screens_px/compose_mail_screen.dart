import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../engine/pixel_route.dart';
import '../models/friend.dart';
import '../repositories/friend_repository.dart';
import '../repositories/mail_repository.dart';
import 'friend_picker_screen.dart';
import 'photo_source_screen.dart';
import 'pixel_text_region.dart';
import 'pixel_ui.dart';

// メール新規作成。件名・本文は自前のテキスト編集。
// 選択中は最下段をソフトキー風の操作バーに切り替える（8pxフォント）。
class ComposeMailScreen extends StatefulWidget {
  const ComposeMailScreen({
    super.key,
    required this.font,
    required this.barFont,
    required this.friendRepository,
    required this.mailRepository,
    this.initialTo,
    this.initialSubject,
  });

  final BdfFont font;
  final BdfFont barFont; // 8ドット（操作バー用）
  final FriendRepository friendRepository;
  final MailRepository mailRepository;
  final Friend? initialTo;
  final String? initialSubject;

  @override
  State<ComposeMailScreen> createState() => _ComposeMailScreenState();
}

class _ComposeMailScreenState extends State<ComposeMailScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _subjectFocus = FocusNode();
  final _bodyFocus = FocusNode();

  late final PixelTextRegion _subjectRegion;
  late final PixelTextRegion _bodyRegion;

  Friend? _to;
  Uint8List? _photo;
  bool _sending = false;
  String? _error;
  int _key = 0;

  bool _caretOn = true;
  Timer? _blink;

  PixelTextRegion? _panRegion;
  int _panLastY = 0;

  // キーボード（入力モード）関連。
  double _prevKb = 0;
  bool _kbUp = false;
  int _visibleRows = 10;
  double _topInsetPx = 0;

  static const int _toY = 20;
  static const int _subjectY = 42;
  static const int _bodyY = 64;
  static const int _bodyH = 36;
  static const int _photoY = 104;
  static const int _sendY = 126;
  static const int _barY = 144; // 操作バー（選択中のみ）

  static const _barLabels = ['コピー', '切取', '貼付', '全選択'];

  @override
  void initState() {
    super.initState();
    _to = widget.initialTo;
    if (widget.initialSubject != null) _subject.text = widget.initialSubject!;

    _subjectRegion = PixelTextRegion(
      controller: _subject, focus: _subjectFocus, font: widget.font,
      x: 4, y: _subjectY, w: 112, h: 18,
      lineHeight: 16, maxLines: 1, singleLine: true,
    );
    _bodyRegion = PixelTextRegion(
      controller: _body, focus: _bodyFocus, font: widget.font,
      x: 4, y: _bodyY, w: 112, h: _bodyH,
      lineHeight: 16, maxLines: 2, singleLine: false,
    );

    for (final l in [_subject, _body]) {
      l.addListener(_bump);
    }
    for (final f in [_subjectFocus, _bodyFocus]) {
      f.addListener(_bump);
    }

    _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _caretOn = !_caretOn;
        _key++;
      });
    });
  }

  void _bump() => setState(() => _key++);

  PixelTextRegion? get _active {
    if (_subjectFocus.hasFocus) return _subjectRegion;
    if (_bodyFocus.hasFocus) return _bodyRegion;
    return null;
  }

  bool get _barVisible => _active?.hasSelection ?? false;

  bool _hit(int y, int top, [int h = PixelUi.buttonH]) =>
      y >= top && y < top + h;

  Future<void> _pickTo() async {
    final friend = await Navigator.of(context).push<Friend>(
      pixelRoute((_) => FriendPickerScreen(
            font: widget.font,
            friendRepository: widget.friendRepository,
          )),
    );
    if (friend != null) {
      setState(() {
        _to = friend;
        _key++;
      });
    }
  }

  Future<void> _pickPhoto() async {
    // 入手方法を選ぶ（カメラ/ギャラリー）。
    final source = await Navigator.of(context).push<ImageSource>(
      pixelRoute((_) => PhotoSourceScreen(font: widget.font)),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // どちらで得た写真も、低画質化は送信時に通す（既存どおり）。
    setState(() {
      _photo = bytes;
      _key++;
    });
  }

  bool get _canSend =>
      _to != null && (_body.text.trim().isNotEmpty || _photo != null);

  Future<void> _send() async {
    if (!_canSend) {
      setState(() {
        _error = 'あて先と本文(か写真)が必要';
        _key++;
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _key++;
    });
    try {
      await widget.mailRepository.sendMail(
        receiverId: _to!.id,
        subject: _subject.text,
        body: _body.text,
        originalPhotoBytes: _photo,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SessionExpiredException {
      // セッション更新も失敗したときだけ、ログインし直しを促す。
      setState(() {
        _error = 'ログインしなおしてね';
        _sending = false;
        _key++;
      });
    } catch (e, st) {
      // 下書き（宛先・件名・本文・写真）は画面に残したまま、失敗だけ知らせる。
      debugPrint('SEND_FAIL: $e');
      debugPrint('$st');
      setState(() {
        _error = 'そうしん失敗';
        _sending = false;
        _key++;
      });
    }
  }

  Future<void> _barAction(int cell) async {
    final r = _active;
    if (r != null) {
      switch (cell) {
        case 0:
          await r.copy();
        case 1:
          await r.cut();
        case 2:
          await r.paste();
        case 3:
          r.selectAll();
      }
    }
    setState(() => _key++);
  }

  // すでにフォーカス済みの欄をタップしたら、IMEを明示的に出す。
  void _tapRegion(PixelTextRegion r, int x, int y) {
    final wasFocused = r.focus.hasFocus;
    r.placeCaret(x, y);
    if (wasFocused) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  void _onTap(int x, int y) {
    if (_sending) return;
    final barY = _kbUp ? (_visibleRows - 1) * 16 : _barY;
    if (_barVisible && y >= barY && y < barY + 16) {
      _barAction((x ~/ 30).clamp(0, 3));
      return;
    }
    if (_kbUp) {
      final r = _active;
      if (r != null && r.contains(x, y)) _tapRegion(r, x, y);
      setState(() => _key++);
      return;
    }
    if (_subjectRegion.contains(x, y)) {
      _tapRegion(_subjectRegion, x, y);
    } else if (_bodyRegion.contains(x, y)) {
      _tapRegion(_bodyRegion, x, y);
    } else if (_hit(y, _toY)) {
      _pickTo();
    } else if (_hit(y, _photoY)) {
      _pickPhoto();
    } else if (_hit(y, _sendY)) {
      _send();
    }
    setState(() => _key++);
  }

  void _onLongPressStart(int x, int y) {
    if (_sending) return;
    PixelTextRegion? r;
    if (_subjectRegion.contains(x, y)) r = _subjectRegion;
    if (_bodyRegion.contains(x, y)) r = _bodyRegion;
    if (r == null) return;
    r.selectAt(x, y);
    setState(() => _key++);
  }

  void _onLongPressMove(int x, int y) {
    _active?.extendTo(x, y);
    setState(() => _key++);
  }

  // 長押しなしのドラッグ＝スクロール。
  void _onPanStart(int x, int y) {
    PixelTextRegion? r;
    if (_subjectRegion.contains(x, y)) r = _subjectRegion;
    if (_bodyRegion.contains(x, y)) r = _bodyRegion;
    _panRegion = r;
    _panLastY = y;
  }

  void _onPanUpdate(int x, int y) {
    final r = _panRegion;
    if (r == null) return;
    final dy = y - _panLastY;
    final lines = dy ~/ 16;
    if (lines != 0) {
      r.scrollByLines(-lines);
      _panLastY += lines * 16;
      setState(() => _key++);
    }
  }

  void _paint(Framebuffer fb) {
    // 入力モード: 見出し＋入力中の欄（拡大）＋操作バーだけを、キーボード上に収める。
    final r = _active;
    if (_kbUp && r != null) {
      final rows = _visibleRows;
      final barOn = r.hasSelection;
      final fieldLines = (rows - 1 - (barOn ? 1 : 0)).clamp(1, 9);
      r.setBox(x: 2, y: 16, w: 116, h: fieldLines * 16, maxLines: fieldLines);

      fb.clear();
      final label = identical(r, _subjectRegion) ? 'けんめい' : 'ほんぶん';
      fb.fillRect(0, 0, Framebuffer.width, 16, on: true);
      fb.drawText(2, 0, label, on: false);
      fb.rect(2, 16, 116, fieldLines * 16, on: true);
      r.draw(fb, caretOn: _caretOn, active: true);
      if (barOn) _drawBar(fb, (rows - 1) * 16);
      return;
    }

    // 通常レイアウト（欄のジオメトリを元に戻す）。
    _subjectRegion.setBox(x: 4, y: _subjectY, w: 112, h: 18, maxLines: 1);
    _bodyRegion.setBox(x: 4, y: _bodyY, w: 112, h: _bodyH, maxLines: 2);

    fb.clear();
    PixelUi.titleBar(fb, 'しんきさくせい');
    PixelUi.field(fb, 4, _toY, 112, _to?.displayName ?? '（あて先をえらぶ）');

    fb.rect(4, _subjectY, 112, 18, on: true);
    _subjectRegion.draw(fb,
        caretOn: _caretOn, active: identical(_active, _subjectRegion));

    fb.rect(4, _bodyY, 112, _bodyH, on: true);
    _bodyRegion.draw(fb,
        caretOn: _caretOn, active: identical(_active, _bodyRegion));

    PixelUi.button(fb, 4, _photoY, 112, _photo == null ? 'しゃしん' : 'しゃしん:あり');
    PixelUi.button(fb, 4, _sendY, 112, _sending ? 'そうしん中…' : 'そうしん');

    if (_error != null) {
      fb.drawText(2, 150, _error!, on: true, clipRight: Framebuffer.width - 2);
    }
    if (_barVisible) _drawBar(fb, _barY);
  }

  // 選択操作バー（1行・8pxフォント）。反転表示。barY に描く。
  void _drawBar(Framebuffer fb, int barY) {
    fb.fillRect(0, barY, Framebuffer.width, 16, on: true);
    for (var i = 0; i < 4; i++) {
      final cx = i * 30;
      if (i > 0) fb.vLine(cx, barY + 2, 12, on: false);
      final label = _barLabels[i];
      final tw = fb.textWidth(label, font: widget.barFont);
      fb.drawText(cx + (30 - tw) ~/ 2, barY + 4, label,
          on: false, font: widget.barFont, clipRight: cx + 29);
    }
  }

  @override
  void dispose() {
    _blink?.cancel();
    _subject.dispose();
    _body.dispose();
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Widget _hiddenInput(TextEditingController c, FocusNode f, bool multiline) =>
      Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: EditableText(
            controller: c,
            focusNode: f,
            maxLines: multiline ? null : 1,
            style: const TextStyle(fontSize: 1, color: Color(0xFF000000)),
            cursorColor: const Color(0xFF000000),
            backgroundCursorColor: const Color(0xFF000000),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final sz = mq.size;
    final cell = min(sz.width ~/ 120, sz.height ~/ 160).clamp(1, 100);
    _topInsetPx = mq.padding.top;
    final availPx = sz.height - kb - _topInsetPx;
    _visibleRows = (availPx ~/ cell).clamp(1, 160);
    _kbUp = kb > 1;

    // キーボードが閉じたらフォーカスを外す（再タップでまた出せるように）。
    if (_prevKb > 1 && kb <= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusManager.instance.primaryFocus?.unfocus();
      });
    }
    _prevKb = kb;

    final repaintKey = _key ^ (_visibleRows << 6) ^ (_kbUp ? 1 << 20 : 0);

    return Stack(
      children: [
        LedCanvas(
          font: widget.font,
          repaintKey: repaintKey,
          alignTop: _kbUp,
          topInset: _topInsetPx,
          paint: _paint,
          onTapDown: _onTap,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMove,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
        ),
        _hiddenInput(_subject, _subjectFocus, false),
        _hiddenInput(_body, _bodyFocus, true),
      ],
    );
  }
}
