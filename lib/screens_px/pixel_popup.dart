import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/text_layout.dart';

// ガラケー風の共通ポップアップ（画面中央の小窓・後ろは見えたまま）。
// OKで閉じる / 自動で閉じる（トースト）/ 閉じない進捗、の3種類。
class PixelPopup {
  PixelPopup._(
    this.message,
    this.font, {
    required this.hasOk,
    required this.autoCloseMs,
    this.onClosed,
  }) {
    _layout();
  }

  // OKで閉じる。閉じたら onClosed を呼ぶ。
  factory PixelPopup.ok(String message, BdfFont font, {void Function()? onClosed}) =>
      PixelPopup._(message, font, hasOk: true, autoCloseMs: 0, onClosed: onClosed);

  // 一定時間で自動的に閉じる（トースト）。
  factory PixelPopup.toast(String message, BdfFont font,
          {int ms = 1500, void Function()? onClosed}) =>
      PixelPopup._(message, font, hasOk: false, autoCloseMs: ms, onClosed: onClosed);

  // 閉じない進捗窓（処理完了まで出しっぱなし）。
  factory PixelPopup.progress(String message, BdfFont font) =>
      PixelPopup._(message, font, hasOk: false, autoCloseMs: 0);

  final String message;
  final BdfFont font;
  final bool hasOk;
  final int autoCloseMs;
  final void Function()? onClosed;

  bool get autoClose => autoCloseMs > 0;

  // 窓のジオメトリ（生成時に確定）。
  static const int _x = 10;
  static const int _w = 100;
  static const int _lineH = 16;
  static const int _maxLines = 6;

  late final int _lines;
  late final int _y;
  late final int _h;
  late final int _okX, _okY, _okW, _okH;

  void _layout() {
    final innerW = _w - 6;
    final total = TextLayout.build(message, font, innerW, _lineH).lineCount;
    _lines = total < _maxLines ? total : _maxLines;
    final contentH = _lines * _lineH;
    _h = 6 + contentH + (hasOk ? 20 : 0);
    _y = ((Framebuffer.height - _h) ~/ 2).clamp(0, Framebuffer.height - _h);
    _okW = 40;
    _okH = 16;
    _okX = _x + (_w - _okW) ~/ 2;
    _okY = _y + _h - _okH - 2;
  }

  void draw(Framebuffer fb) {
    // 窓の内側を消灯で塗ってから枠を描く（窓の外は背後が見えたまま）。
    fb.fillRect(_x, _y, _w, _h, on: false);
    fb.rect(_x, _y, _w, _h, on: true);
    fb.drawTextWrapped(_x + 3, _y + 3, _w - 6, _lineH, _lines, message, on: true);
    if (hasOk) {
      fb.rect(_okX, _okY, _okW, _okH, on: true);
      final tw = fb.textWidth('OK');
      fb.drawText(_okX + (_okW - tw) ~/ 2, _okY, 'OK', on: true);
    }
  }

  // OKボタンのタップか。
  bool hitOk(int x, int y) =>
      hasOk && x >= _okX && x < _okX + _okW && y >= _okY && y < _okY + _okH;
}
