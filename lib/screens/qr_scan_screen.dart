import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../repositories/friend_repository.dart';

// 相手のQRを読み取って友達になる画面。
// 成功したらtrueを返して閉じる（呼び出し元が一覧を更新する）。
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.friendRepository});

  final FriendRepository friendRepository;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();

  // 連続で読み取ってしまわないよう、処理中フラグで1回に絞る。
  bool _handling = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _handling = true);
    final result = await widget.friendRepository.redeemToken(raw);
    if (!mounted) return;

    final message = switch (result) {
      RedeemResult.success => '友達になりました',
      RedeemResult.alreadyFriends => 'すでに友達です',
      RedeemResult.expired => 'QRコードの有効期限が切れています',
      RedeemResult.used => 'このQRコードは使用済みです',
      RedeemResult.selfQr => '自分のQRコードは読み取れません',
      RedeemResult.invalid => '無効なQRコードです',
      RedeemResult.error => '読み取りに失敗しました',
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    if (result == RedeemResult.success) {
      Navigator.of(context).pop(true);
    } else {
      // 失敗時は、少し待ってからまた読み取れるようにする。
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _handling = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRを読み取る')),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
