import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/mail.dart';
import '../repositories/mail_repository.dart';

// QR交換が成立した瞬間に出すポップアップ。
// 相手から届いた自己紹介写真を一時的に表示する。
class ExchangeResultDialog extends StatefulWidget {
  const ExchangeResultDialog({
    super.key,
    required this.mailRepository,
    required this.friendId,
    required this.friendName,
  });

  final MailRepository mailRepository;
  final String friendId;
  final String friendName;

  @override
  State<ExchangeResultDialog> createState() => _ExchangeResultDialogState();
}

class _ExchangeResultDialogState extends State<ExchangeResultDialog> {
  late Future<Uint8List?> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = _loadFriendPhoto();
  }

  // 相手から届いた自己紹介写真を取得する。未設定ならnull。
  Future<Uint8List?> _loadFriendPhoto() async {
    final mails = await widget.mailRepository.fetchConversation(widget.friendId);
    // 相手から届いた、写真つきのメール（＝1通目の自己紹介）を探す。
    for (final Mail m in mails.reversed) {
      if (!m.isMine && m.hasPhoto) {
        return widget.mailRepository.downloadPhoto(m.photoPath!);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '友達に追加しました',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('${widget.friendName} さん'),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<Uint8List?>(
                  future: _photoFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final theirs = snapshot.data;
                    if (theirs == null) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('相手は自己紹介写真を設定していませんでした'),
                      );
                    }
                    return SingleChildScrollView(
                      child: Image.memory(
                        theirs,
                        filterQuality: FilterQuality.none,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('とじる'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
