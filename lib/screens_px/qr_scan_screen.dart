import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../repositories/friend_repository.dart';

// QR読み取り。カメラプレビューはOSネイティブUIのため、例外として全画面表示する。
// 交換の結果(RedeemOutcome)を返して閉じる。Androidの戻るボタンでキャンセル。
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.friendRepository});

  final FriendRepository friendRepository;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handling = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _handling = true);
    final outcome = await widget.friendRepository.redeemToken(raw);
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
