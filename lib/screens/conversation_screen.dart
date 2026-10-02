import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/mail.dart';
import '../repositories/mail_repository.dart';
import 'compose_mail_screen.dart';

// 特定の友達とのメールのやり取りを表示する画面。
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.mailRepository,
    required this.friendId,
    required this.friendName,
  });

  final MailRepository mailRepository;
  final String friendId;
  final String friendName;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late Future<List<Mail>> _mailsFuture;

  // 添付写真は一度だけダウンロードして使い回す。
  final _photoCache = <String, Future<Uint8List>>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _mailsFuture = widget.mailRepository.fetchConversation(widget.friendId);
  }

  Future<void> _openCompose() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComposeMailScreen(
          mailRepository: widget.mailRepository,
          receiverId: widget.friendId,
          receiverName: widget.friendName,
        ),
      ),
    );
    if (sent == true && mounted) setState(_reload);
  }

  Future<Uint8List> _photo(String path) =>
      _photoCache.putIfAbsent(path, () => widget.mailRepository.downloadPhoto(path));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.friendName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit),
        label: const Text('書く'),
      ),
      body: FutureBuilder<List<Mail>>(
        future: _mailsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('メールの取得に失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mails = snapshot.data!;
          if (mails.isEmpty) {
            return const Center(child: Text('まだやり取りがありません。'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: mails.length,
            itemBuilder: (context, index) => _MailBubble(
              mail: mails[index],
              photoLoader: _photo,
            ),
          );
        },
      ),
    );
  }
}

class _MailBubble extends StatelessWidget {
  const _MailBubble({required this.mail, required this.photoLoader});

  final Mail mail;
  final Future<Uint8List> Function(String path) photoLoader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor =
        mail.isMine ? scheme.primaryContainer : scheme.surfaceContainerHighest;

    return Align(
      alignment: mail.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mail.subject != null)
              Text(
                mail.subject!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (mail.body != null) Text(mail.body!),
            if (mail.hasPhoto) ...[
              const SizedBox(height: 8),
              FutureBuilder<Uint8List>(
                future: photoLoader(mail.photoPath!),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('写真を読み込めませんでした');
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    filterQuality: FilterQuality.none,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
