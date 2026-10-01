import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/garakei_photo_service.dart';

// ガラケー画質化の見た目を確認するための、開発中だけ使う画面。
// 確認が終わったら削除する。
class DebugPhotoPreviewScreen extends StatefulWidget {
  const DebugPhotoPreviewScreen({super.key});

  @override
  State<DebugPhotoPreviewScreen> createState() =>
      _DebugPhotoPreviewScreenState();
}

// 確認は、一般的なスマホ幅の半分（540px）に縮小して行う。
const _targetWidth = 540;

class _DebugPhotoPreviewScreenState extends State<DebugPhotoPreviewScreen> {
  Uint8List? _processed;
  bool _isLoading = false;

  Future<void> _pickAndProcess() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _isLoading = true;
      _processed = null;
    });

    final originalBytes = await picked.readAsBytes();
    // dotsAcrossなどは指定せず、確定した標準設定（ドット密度100）で変換する。
    final processedBytes = await GarakeiPhotoService.process(
      originalBytes,
      targetWidth: _targetWidth,
    );

    setState(() {
      _processed = processedBytes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('画質変換の確認（開発用）')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FilledButton(
              onPressed: _isLoading ? null : _pickAndProcess,
              child: const Text('写真を選ぶ'),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const CircularProgressIndicator(),
            if (_processed != null) ...[
              const Text('変換後（ドット密度100）'),
              const SizedBox(height: 4),
              Image.memory(
                _processed!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
