import 'dart:async';
import 'dart:typed_data';

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
import 'pixel_text_region.dart';
import 'pixel_ui.dart';

// メール新規作成。件名・本文は自前のテキスト編集（カーソル/選択/変換中/自作メニュー）。
class ComposeMailScreen extends StatefulWidget {
  const ComposeMailScreen({
    super.key,
    required this.font,
    required this.friendRepository,
    required this.mailRepository,
    this.initialTo,
    this.initialSubject,
  });

  final BdfFont font;
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
  bool _menuForced = false;
  Timer? _blink;

  static const int _toY = 20;
  static const int _subjectY = 42;
  static const int _bodyY = 64;
  static const int _bodyH = 36;
  static const int _photoY = 104;
  static const int _sendY = 126;

  // 自作メニュー（選択/長押し時）の領域。
  static const int _menuX = 8, _menuY = 22, _menuW = 104, _menuRowTop = 24;
  static const _menuLabels = ['コピー', 'きりとり', 'はりつけ', 'ぜんせんたく'];

  @override
  void initState() {
    super.initState();
    _to = widget.initialTo;
    if (widget.initialSubject != null) _subject.text = widget.initialSubject!;

    _subjectRegion = PixelTextRegion(
      controller: _subject,
      focus: _subjectFocus,
      font: widget.font,
      x: 4, y: _subjectY, w: 112, h: 18,
      lineHeight: 16, maxLines: 1, singleLine: true,
    );
    _bodyRegion = PixelTextRegion(
      controller: _body,
      focus: _bodyFocus,
      font: widget.font,
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

  bool get _menuVisible => _menuForced || (_active?.hasSelection ?? false);

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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
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
    } catch (e) {
      setState(() {
        _error = 'そうしん失敗';
        _sending = false;
        _key++;
      });
    }
  }

  Future<void> _menuAction(int row) async {
    final r = _active;
    if (r != null) {
      switch (row) {
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
    setState(() {
      _menuForced = false;
      _key++;
    });
  }

  void _onTap(int x, int y) {
    if (_sending) return;
    // メニューが出ているときは最優先で処理。
    if (_menuVisible &&
        x >= _menuX &&
        x < _menuX + _menuW &&
        y >= _menuRowTop &&
        y < _menuRowTop + 4 * 16) {
      _menuAction((y - _menuRowTop) ~/ 16);
      return;
    }
    setState(() {
      _menuForced = false;
      _key++;
    });
    if (_subjectRegion.contains(x, y)) {
      _subjectRegion.placeCaret(x, y);
    } else if (_bodyRegion.contains(x, y)) {
      _bodyRegion.placeCaret(x, y);
    } else if (_hit(y, _toY)) {
      _pickTo();
    } else if (_hit(y, _photoY)) {
      _pickPhoto();
    } else if (_hit(y, _sendY)) {
      _send();
    }
  }

  void _onLongPressStart(int x, int y) {
    if (_sending) return;
    PixelTextRegion? r;
    if (_subjectRegion.contains(x, y)) r = _subjectRegion;
    if (_bodyRegion.contains(x, y)) r = _bodyRegion;
    if (r == null) return;
    r.selectAt(x, y);
    setState(() {
      _menuForced = true;
      _key++;
    });
  }

  void _onLongPressMove(int x, int y) {
    _active?.extendTo(x, y);
    setState(() => _key++);
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'しんきさくせい');

    PixelUi.field(fb, 4, _toY, 112, _to?.displayName ?? '（あて先をえらぶ）');

    // 件名欄（枠）＋編集描画。
    fb.rect(4, _subjectY, 112, 18, on: true);
    _subjectRegion.draw(fb,
        caretOn: _caretOn, active: identical(_active, _subjectRegion));

    // 本文欄（枠）＋編集描画。
    fb.rect(4, _bodyY, 112, _bodyH, on: true);
    _bodyRegion.draw(fb,
        caretOn: _caretOn, active: identical(_active, _bodyRegion));

    PixelUi.button(fb, 4, _photoY, 112, _photo == null ? 'しゃしん' : 'しゃしん:あり');
    PixelUi.button(fb, 4, _sendY, 112, _sending ? 'そうしん中…' : 'そうしん');

    if (_error != null) fb.drawTextCentered(150, _error!, on: true);

    if (_menuVisible) _drawMenu(fb);
  }

  void _drawMenu(Framebuffer fb) {
    fb.fillRect(_menuX, _menuY, _menuW, 4 * 16 + 4, on: false);
    fb.rect(_menuX, _menuY, _menuW, 4 * 16 + 4, on: true);
    for (var i = 0; i < _menuLabels.length; i++) {
      fb.drawText(_menuX + 4, _menuRowTop + i * 16, _menuLabels[i],
          on: true, clipRight: _menuX + _menuW - 4);
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
    return Stack(
      children: [
        LedCanvas(
          font: widget.font,
          repaintKey: _key,
          paint: _paint,
          onTapDown: _onTap,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMove,
        ),
        _hiddenInput(_subject, _subjectFocus, false),
        _hiddenInput(_body, _bodyFocus, true),
      ],
    );
  }
}
