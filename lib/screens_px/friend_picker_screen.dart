import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../models/friend.dart';
import '../repositories/friend_repository.dart';
import 'pixel_ui.dart';

// 宛先を電話帳（交換済みの友達）から選ぶ画面。選んだ Friend を返す。
class FriendPickerScreen extends StatefulWidget {
  const FriendPickerScreen({
    super.key,
    required this.font,
    required this.friendRepository,
  });

  final BdfFont font;
  final FriendRepository friendRepository;

  @override
  State<FriendPickerScreen> createState() => _FriendPickerScreenState();
}

class _FriendPickerScreenState extends State<FriendPickerScreen> {
  List<Friend> _friends = [];
  bool _loaded = false;
  int _key = 0;

  static const int _listTop = 20;
  static const int _rowH = 16;
  static const int _maxRows = 8;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.friendRepository.fetchFriends();
      if (mounted) {
        setState(() {
          _friends = list;
          _loaded = true;
          _key++;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _key++;
        });
      }
    }
  }

  void _onTap(int x, int y) {
    if (y < _listTop) return;
    final idx = (y - _listTop) ~/ _rowH;
    if (idx >= 0 && idx < _friends.length && idx < _maxRows) {
      Navigator.of(context).pop(_friends[idx]);
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'あて先をえらぶ');
    if (!_loaded) {
      fb.drawText(4, _listTop, 'よみこみ中…', on: true);
      return;
    }
    if (_friends.isEmpty) {
      fb.drawText(4, _listTop, 'ともだちがいません', on: true);
      return;
    }
    final count = _friends.length < _maxRows ? _friends.length : _maxRows;
    for (var i = 0; i < count; i++) {
      final y = _listTop + i * _rowH;
      fb.drawText(4, y, _friends[i].displayName,
          on: true, clipRight: Framebuffer.width - 2);
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
