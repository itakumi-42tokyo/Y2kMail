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

// 比較のため、圧縮率（quality）違いのパターンを並べて出す。
// 数字が小さいほど圧縮率が高く、荒くなる。
// 今はブロックノイズなし（高品質）を基準に、色味だけを確認する。
const _qualityPatterns = [95, 90];

class _DebugPhotoPreviewScreenState extends State<DebugPhotoPreviewScreen> {
  Uint8List? _original;
  Map<int, Uint8List>? _processedByQuality;
  bool _isLoading = false;

  Future<void> _pickAndProcess() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _isLoading = true;
      _original = null;
      _processedByQuality = null;
    });

    final originalBytes = await picked.readAsBytes();

    final results = <int, Uint8List>{};
    for (final quality in _qualityPatterns) {
      results[quality] = await GarakeiPhotoService.process(
        originalBytes,
        quality: quality,
      );
    }

    setState(() {
      _original = originalBytes;
      _processedByQuality = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processedByQuality;
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
            if (_original != null) ...[
              Text('元の写真（${(_original!.length / 1024).toStringAsFixed(1)} KB）'),
              Image.memory(_original!),
            ],
            if (processed != null)
              for (final quality in _qualityPatterns) ...[
                const SizedBox(height: 16),
                Text(
                  'quality: $quality '
                  '（${(processed[quality]!.length / 1024).toStringAsFixed(1)} KB）',
                ),
                Image.memory(processed[quality]!),
              ],
          ],
        ),
      ),
    );
  }
}
