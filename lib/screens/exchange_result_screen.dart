import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/mail.dart';
import '../repositories/mail_repository.dart';
import '../repositories/profile_repository.dart';

// QR交換が成立した直後に出す演出画面。
// 相手から届いた自己紹介写真と、自分が送った自己紹介写真を並べて見せる。
class ExchangeResultScreen extends StatefulWidget {
  const ExchangeResultScreen({
    super.key,
    required this.mailRepository,
    required this.profileRepository,
    required this.friendId,
    required this.friendName,
  });

  final MailRepository mailRepository;
  final ProfileRepository profileRepository;
  final String friendId;
  final String friendName;

  @override
  State<ExchangeResultScreen> createState() => _ExchangeResultScreenState();
}

class _ExchangeResultScreenState extends State<ExchangeResultScreen> {
  late Future<(Uint8List?, Uint8List?)> _photosFuture;

  @override
  void initState() {
    super.initState();
    _photosFuture = _loadPhotos();
  }

  // (相手の自己紹介写真, 自分の自己紹介写真) を取得する。どちらも未設定ならnull。
  Future<(Uint8List?, Uint8List?)> _loadPhotos() async {
    final mine = await widget.profileRepository.fetchIntroPhoto();

    Uint8List? theirs;
    final mails = await widget.mailRepository.fetchConversation(widget.friendId);
    // 相手から届いた、写真つきのメール（＝1通目の自己紹介）を探す。
    for (final Mail m in mails.reversed) {
      if (!m.isMine && m.hasPhoto) {
        theirs = await widget.mailRepository.downloadPhoto(m.photoPath!);
        break;
      }
    }
    return (theirs, mine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('交換成立')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.friendName} さんと交換しました！',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<(Uint8List?, Uint8List?)>(
                future: _photosFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final (theirs, mine) = snapshot.data!;
                  return ListView(
                    children: [
                      _PhotoBlock(
                        label: '${widget.friendName} さんの自己紹介',
                        bytes: theirs,
                      ),
                      const SizedBox(height: 24),
                      _PhotoBlock(label: 'あなたが送った自己紹介', bytes: mine),
                    ],
                  );
                },
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('とじる'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({required this.label, required this.bytes});

  final String label;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (bytes != null)
          Image.memory(bytes!, filterQuality: FilterQuality.none)
        else
          const Text('（自己紹介写真は未設定でした）'),
      ],
    );
  }
}
