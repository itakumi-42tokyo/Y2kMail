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
import 'pixel_ui.dart';

// メール新規作成。宛先（電話帳から選択）/ 件名 / 本文 / 添付 / 送信。
// 返信でも使えるよう、初期の宛先・件名を受け取れる。
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

  Friend? _to;
  Uint8List? _photo;
  bool _sending = false;
  String? _error;
  int _key = 0;

  static const int _toY = 20;
  static const int _subjectY = 42;
  static const int _bodyY = 64;
  static const int _bodyH = 42;
  static const int _photoY = 112;
  static const int _sendY = 134;

  @override
  void initState() {
    super.initState();
    _to = widget.initialTo;
    if (widget.initialSubject != null) _subject.text = widget.initialSubject!;
    _subject.addListener(_bump);
    _body.addListener(_bump);
    _subjectFocus.addListener(_bump);
    _bodyFocus.addListener(_bump);
  }

  void _bump() => setState(() => _key++);

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

  void _onTap(int x, int y) {
    if (_sending) return;
    if (_hit(y, _toY)) {
      _pickTo();
    } else if (_hit(y, _subjectY)) {
      _subjectFocus.requestFocus();
    } else if (_hit(y, _bodyY, _bodyH)) {
      _bodyFocus.requestFocus();
    } else if (_hit(y, _photoY)) {
      _pickPhoto();
    } else if (_hit(y, _sendY)) {
      _send();
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'しんきさくせい');

    // 宛先。
    PixelUi.field(fb, 4, _toY, 112, _to?.displayName ?? '（あて先をえらぶ）');
    // 件名。
    PixelUi.field(fb, 4, _subjectY, 112, _subject.text,
        focused: _subjectFocus.hasFocus);

    // 本文（枠内に折り返し表示）。
    fb.rect(4, _bodyY, 112, _bodyH, on: true);
    if (_bodyFocus.hasFocus) fb.rect(5, _bodyY + 1, 110, _bodyH - 2, on: true);
    fb.drawTextWrapped(7, _bodyY + 2, 104, 16, 2, _body.text, on: true);

    // 添付。
    PixelUi.button(fb, 4, _photoY, 112, _photo == null ? 'しゃしん' : 'しゃしん:あり');
    // 送信。
    PixelUi.button(fb, 4, _sendY, 112, _sending ? 'そうしん中…' : 'そうしん');

    if (_error != null) fb.drawTextCentered(154, _error!, on: true);
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Widget _hiddenInput(TextEditingController c, FocusNode f) => Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: EditableText(
            controller: c,
            focusNode: f,
            maxLines: null,
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
        ),
        _hiddenInput(_subject, _subjectFocus),
        _hiddenInput(_body, _bodyFocus),
      ],
    );
  }
}
