import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../repositories/friend_repository.dart';

// 自分の交換用QRを表示する画面。相手にこれを読み取ってもらう。
class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key, required this.friendRepository});

  final FriendRepository friendRepository;

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  late Future<String> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = widget.friendRepository.issueExchangeToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('赤外線送信')),
      body: Center(
        child: FutureBuilder<String>(
          future: _tokenFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('QRの発行に失敗しました。通信環境を確認してください。');
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ガラケーらしい「赤外線送信中…」の演出。
                const _InfraredLabel(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: QrImageView(
                    data: snapshot.data!,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 24),
                const Text('相手にこのQRを読み取ってもらってください'),
                const Text(
                  '※5分で無効になります',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                // 開発用: トークン文字列。動作確認が済んだら削除する。
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SelectableText(
                    '開発用トークン: ${snapshot.data!}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 「赤外線送信中…」の点滅アニメーション。
class _InfraredLabel extends StatefulWidget {
  const _InfraredLabel();

  @override
  State<_InfraredLabel> createState() => _InfraredLabelState();
}

class _InfraredLabelState extends State<_InfraredLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        '赤外線送信中…',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
