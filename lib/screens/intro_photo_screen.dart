import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/profile_repository.dart';

// 自己紹介写真を設定する画面。
// ここで設定した写真が、QR交換の成立時に1通目として相手へ届く。
class IntroPhotoScreen extends StatefulWidget {
  const IntroPhotoScreen({super.key, required this.profileRepository});

  final ProfileRepository profileRepository;

  @override
  State<IntroPhotoScreen> createState() => _IntroPhotoScreenState();
}

class _IntroPhotoScreenState extends State<IntroPhotoScreen> {
  late Future<Uint8List?> _currentFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentFuture = widget.profileRepository.fetchIntroPhoto();
  }

  Future<void> _pickAndSave() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await picked.readAsBytes();
      await widget.profileRepository.setIntroPhoto(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自己紹介写真を設定しました')),
      );
      setState(() {
        _currentFuture = widget.profileRepository.fetchIntroPhoto();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自己紹介写真')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '友達交換したとき、相手に最初に届く写真です。\nガラケー画質に加工されて届きます。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<Uint8List?>(
                future: _currentFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData &&
                      snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return const Center(child: Text('まだ設定されていません'));
                  }
                  return Center(
                    child: Image.memory(
                      bytes,
                      filterQuality: FilterQuality.none,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _pickAndSave,
              icon: const Icon(Icons.photo),
              label: Text(_isSaving ? '保存中…' : '写真を選ぶ'),
            ),
          ],
        ),
      ),
    );
  }
}
