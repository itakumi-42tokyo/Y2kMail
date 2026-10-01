import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/mail_repository.dart';

// メールを作成して送る画面。送信に成功したらtrueを返して閉じる。
class ComposeMailScreen extends StatefulWidget {
  const ComposeMailScreen({
    super.key,
    required this.mailRepository,
    required this.receiverId,
    required this.receiverName,
  });

  final MailRepository mailRepository;
  final String receiverId;
  final String receiverName;

  @override
  State<ComposeMailScreen> createState() => _ComposeMailScreenState();
}

class _ComposeMailScreenState extends State<ComposeMailScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  Uint8List? _photoBytes;
  bool _isSending = false;
  String? _errorMessage;

  bool get _canSend =>
      _bodyController.text.trim().isNotEmpty || _photoBytes != null;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await widget.mailRepository.sendMail(
        receiverId: widget.receiverId,
        subject: _subjectController.text,
        body: _bodyController.text,
        originalPhotoBytes: _photoBytes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.receiverName} へ送る')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _subjectController,
              maxLength: 15,
              decoration: const InputDecoration(labelText: '件名（任意・15文字まで）'),
            ),
            TextField(
              controller: _bodyController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '本文',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (_photoBytes != null) ...[
              // 送信前のプレビューは元の写真。加工は送信時に端末内で行う。
              Image.memory(_photoBytes!, height: 160, fit: BoxFit.contain),
              TextButton(
                onPressed: () => setState(() => _photoBytes = null),
                child: const Text('写真を取り消す'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo),
                label: const Text('写真を添付'),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_isSending || !_canSend) ? null : _send,
              child: Text(_isSending ? '送信中…' : '送信'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
