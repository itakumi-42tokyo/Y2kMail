import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/pixel_canvas.dart';
import '../engine/pixel_route.dart';
import '../models/friend.dart';
import '../repositories/friend_repository.dart';
import 'manual_token_screen.dart';
import 'pixel_ui.dart';
import 'qr_display_screen.dart';
import 'qr_scan_screen.dart';

// 電話帳（ピクセル描画）。友達一覧とQR表示/読み取り/手入力の入口。
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.font,
    required this.friendRepository,
  });

  final BdfFont font;
  final FriendRepository friendRepository;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Friend> _friends = [];
  bool _loaded = false;
  int _selected = -1;
  String _message = '';
  int _key = 0;

  // レイアウト（整数ドット）。
  static const int _showY = 20;
  static const int _scanY = 20;
  static const int _manualY = 40;
  static const int _listTop = 62;
  static const int _rowH = 16;
  static const int _maxRows = 5;

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

  Future<void> _showQr() async {
    await Navigator.of(context).push(pixelRoute((_) => QrDisplayScreen(
        font: widget.font,
        friendRepository: widget.friendRepository,
      ),
    ));
  }

  Future<void> _scanQr() async {
    final outcome = await Navigator.of(context).push<RedeemOutcome>(
      pixelRoute((_) => QrScanScreen(friendRepository: widget.friendRepository),
      ),
    );
    if (outcome != null) _handleOutcome(outcome);
  }

  Future<void> _manual() async {
    final token = await Navigator.of(context).push<String>(
      pixelRoute((_) => ManualTokenScreen(font: widget.font),
      ),
    );
    if (token == null || token.isEmpty) return;
    final outcome = await widget.friendRepository.redeemToken(token);
    if (mounted) _handleOutcome(outcome);
  }

  void _handleOutcome(RedeemOutcome o) {
    final msg = switch (o.result) {
      RedeemResult.success => '${o.friendName ?? ''}とともだちに',
      RedeemResult.alreadyFriends => 'すでにともだち',
      RedeemResult.expired => 'きげんぎれ',
      RedeemResult.used => 'つかいずみ',
      RedeemResult.selfQr => 'じぶんのQR',
      RedeemResult.invalid => 'むこうなQR',
      RedeemResult.error => 'しっぱい',
    };
    setState(() {
      _message = msg;
      _key++;
    });
    if (o.result == RedeemResult.success) _load();
  }

  void _onTap(int x, int y) {
    // ボタン行。
    if (y >= _showY && y < _showY + PixelUi.buttonH) {
      if (x < 60) {
        _showQr();
      } else {
        _scanQr();
      }
      return;
    }
    if (y >= _manualY && y < _manualY + PixelUi.buttonH) {
      _manual();
      return;
    }
    // 一覧。
    if (y >= _listTop) {
      final idx = (y - _listTop) ~/ _rowH;
      if (idx >= 0 && idx < _friends.length && idx < _maxRows) {
        if (idx == _selected) {
          // いまは会話画面が未移植なので案内だけ。
          setState(() {
            _message = 'かいわは準備中';
            _key++;
          });
        } else {
          setState(() {
            _selected = idx;
            _key++;
          });
        }
      }
    }
  }

  void _paint(Framebuffer fb) {
    fb.clear();
    PixelUi.titleBar(fb, 'でんわちょう');

    PixelUi.button(fb, 4, _showY, 54, 'みせる');
    PixelUi.button(fb, 62, _scanY, 54, 'よむ');
    PixelUi.button(fb, 4, _manualY, 112, 'てにゅうりょく');

    if (!_loaded) {
      fb.drawText(4, _listTop, 'よみこみ中…', on: true);
    } else if (_friends.isEmpty) {
      fb.drawText(4, _listTop, 'ともだちなし', on: true);
    } else {
      final count = _friends.length < _maxRows ? _friends.length : _maxRows;
      for (var i = 0; i < count; i++) {
        final y = _listTop + i * _rowH;
        if (i == _selected) {
          fb.fillRect(0, y, Framebuffer.width, _rowH, on: true);
          fb.drawText(2, y, '>', on: false);
          fb.drawText(14, y, _friends[i].displayName,
              on: false, clipRight: Framebuffer.width - 2);
        } else {
          fb.drawText(14, y, _friends[i].displayName,
              on: true, clipRight: Framebuffer.width - 2);
        }
      }
    }

    if (_message.isNotEmpty) {
      fb.drawTextCentered(146, _message, on: true);
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
