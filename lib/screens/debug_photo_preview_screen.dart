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

// 気に入ってもらえた「全部強め」の設定を固定のベースにする。
const _baseBlurRadius = 2;
const _baseNoiseSigma = 10.0;
const _baseVignetteAmount = 0.6;
const _baseChromaticAberrationShift = 3;

class _Pattern {
  const _Pattern(
    this.label, {
    this.screenDoorCellSize = 0,
    this.screenDoorDarken = 0.35,
  });

  final String label;
  final int screenDoorCellSize;
  final double screenDoorDarken;
}

// ベースは気に入ってもらえた「全部強め」。そこに液晶の格子模様を足して比較する。
const _patterns = [
  _Pattern('全部強め（格子なし・前回の案）'),
  _Pattern('+ 格子 cell=2', screenDoorCellSize: 2),
  _Pattern('+ 格子 cell=3', screenDoorCellSize: 3),
  _Pattern('+ 格子 cell=4', screenDoorCellSize: 4),
  _Pattern('+ 格子 cell=3・濃いめ', screenDoorCellSize: 3, screenDoorDarken: 0.5),
];

class _DebugPhotoPreviewScreenState extends State<DebugPhotoPreviewScreen> {
  Uint8List? _original;
  Map<String, Uint8List>? _processedByLabel;
  bool _isLoading = false;

  Future<void> _pickAndProcess() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _isLoading = true;
      _original = null;
      _processedByLabel = null;
    });

    final originalBytes = await picked.readAsBytes();

    final results = <String, Uint8List>{};
    for (final pattern in _patterns) {
      results[pattern.label] = await GarakeiPhotoService.process(
        originalBytes,
        blurRadius: _baseBlurRadius,
        noiseSigma: _baseNoiseSigma,
        vignetteAmount: _baseVignetteAmount,
        chromaticAberrationShift: _baseChromaticAberrationShift,
        screenDoorCellSize: pattern.screenDoorCellSize,
        screenDoorDarken: pattern.screenDoorDarken,
      );
    }

    setState(() {
      _original = originalBytes;
      _processedByLabel = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processedByLabel;
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
              const Text('元の写真'),
              Image.memory(_original!),
            ],
            if (processed != null)
              for (final pattern in _patterns) ...[
                const SizedBox(height: 16),
                Text(pattern.label),
                Image.memory(processed[pattern.label]!),
              ],
          ],
        ),
      ),
    );
  }
}
