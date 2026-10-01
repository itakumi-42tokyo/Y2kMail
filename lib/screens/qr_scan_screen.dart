import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../repositories/friend_repository.dart';

// 相手のQRを読み取って友達になる画面。
// 読み取って交換を試みた結果（RedeemOutcome）を返して閉じる。
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
    final outcome = await widget.friendRepository.redeemToken(raw);
    if (!mounted) return;
    // 結果は呼び出し元（電話帳）に返して、そちらで演出・メッセージを出す。
    Navigator.of(context).pop(outcome);
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
