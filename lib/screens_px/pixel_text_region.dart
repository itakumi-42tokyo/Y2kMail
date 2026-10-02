import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/text_layout.dart';

// 1つの入力欄（件名=単一行 / 本文=複数行）の、
// カーソル・選択・変換中の描画と、タップ/長押し/ドラッグの処理をまとめる。
// 正本は controller.value（TextEditingValue）。この層は状態を持たない（スクロール位置だけ保持）。
class PixelTextRegion {
  PixelTextRegion({
    required this.controller,
    required this.focus,
    required this.font,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.lineHeight,
    required this.maxLines,
    required this.singleLine,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final BdfFont font;
  final int x, y, w, h, lineHeight, maxLines;
  final bool singleLine;

  static const int _pad = 2;

  int _scrollX = 0; // 単一行の横スクロール
  int _firstLine = 0; // 複数行の先頭表示行

  int get _ox => x + _pad;
  int get _oy => y + _pad;
  int get _innerW => w - _pad * 2;
  int get _clipR => x + w - _pad - 1;

  TextLayout _layout() {
    return TextLayout.build(
      controller.text,
      font,
      singleLine ? 1 << 20 : _innerW,
      lineHeight,
    );
  }

  bool contains(int lx, int ly) =>
      lx >= x && lx < x + w && ly >= y && ly < y + h;

  TextSelection get _sel => controller.selection;

  bool get hasSelection => _sel.isValid && !_sel.isCollapsed;

  // 正本を更新する（選択/文字列）。変換中は打ち切る。
  void _setValue(String text, TextSelection sel) {
    controller.value = TextEditingValue(text: text, selection: sel);
  }

  int _indexAt(int lx, int ly, TextLayout l) {
    if (singleLine) {
      return l.indexAt(lx - _ox + _scrollX, 0);
    }
    final li = _firstLine + ((ly - _oy) ~/ lineHeight);
    final py = (li < 0 ? 0 : li) * lineHeight;
    return l.indexAt(lx - _ox, py);
  }

  void placeCaret(int lx, int ly) {
    focus.requestFocus();
    final l = _layout();
    final i = _indexAt(lx, ly, l);
    _setValue(controller.text, TextSelection.collapsed(offset: i));
    _ensureVisible();
  }

  // 長押し: その位置の1文字を選択（位置が文字境界なら折り返しに応じて1文字）。
  void selectAt(int lx, int ly) {
    focus.requestFocus();
    final l = _layout();
    final i = _indexAt(lx, ly, l);
    final n = controller.text.length;
    final a = i.clamp(0, n);
    final b = (i + 1).clamp(0, n);
    _setValue(controller.text, TextSelection(baseOffset: a, extentOffset: b));
    _ensureVisible();
  }

  // ドラッグ: 選択の端（extent）を伸縮する。
  void extendTo(int lx, int ly) {
    final l = _layout();
    final i = _indexAt(lx, ly, l);
    _setValue(
      controller.text,
      TextSelection(baseOffset: _sel.baseOffset, extentOffset: i),
    );
    _ensureVisible();
  }

  void _ensureVisible() {
    final l = _layout();
    final ext = _sel.extentOffset.clamp(0, controller.text.length);
    final (line, cx) = l.caretPos(ext);
    if (singleLine) {
      if (cx - _scrollX > _innerW) _scrollX = cx - _innerW;
      if (cx - _scrollX < 0) _scrollX = cx;
      if (_scrollX < 0) _scrollX = 0;
    } else {
      if (line < _firstLine) _firstLine = line;
      if (line >= _firstLine + maxLines) _firstLine = line - maxLines + 1;
      if (_firstLine < 0) _firstLine = 0;
    }
  }

  // クリップボード操作。
  Future<void> copy() async {
    if (!hasSelection) return;
    await Clipboard.setData(ClipboardData(text: _sel.textInside(controller.text)));
  }

  Future<void> cut() async {
    if (!hasSelection) return;
    final text = controller.text;
    final start = _sel.start, end = _sel.end;
    await Clipboard.setData(ClipboardData(text: text.substring(start, end)));
    _setValue(text.replaceRange(start, end, ''),
        TextSelection.collapsed(offset: start));
    _ensureVisible();
  }

  Future<void> paste() async {
    final data = await Clipboard.getData('text/plain');
    final ins = data?.text ?? '';
    if (ins.isEmpty) return;
    final text = controller.text;
    final start = _sel.isValid ? _sel.start : text.length;
    final end = _sel.isValid ? _sel.end : text.length;
    final filtered = singleLine ? ins.replaceAll('\n', '') : ins;
    _setValue(
      text.replaceRange(start, end, filtered),
      TextSelection.collapsed(offset: start + filtered.length),
    );
    _ensureVisible();
  }

  void selectAll() {
    final n = controller.text.length;
    if (n == 0) return;
    _setValue(controller.text, TextSelection(baseOffset: 0, extentOffset: n));
  }

  // 描画。枠は呼び出し側が描く。ここは文字・選択・カーソル・変換下線を描く。
  void draw(Framebuffer fb, {required bool caretOn, required bool active}) {
    final l = _layout();
    final text = controller.text;
    _ensureVisible();

    final firstVis = singleLine ? 0 : _firstLine;
    final lastVis = singleLine ? 0 : (_firstLine + maxLines - 1);

    for (var li = firstVis; li <= lastVis && li < l.lineCount; li++) {
      final line = l.lines[li];
      final sy = _oy + (li - firstVis) * lineHeight;
      final sx = _ox - (singleLine ? _scrollX : 0);
      final lineText = text.substring(line.start, line.end);
      fb.drawText(sx, sy, lineText, on: true, clipLeft: _ox, clipRight: _clipR);
    }

    // 選択の反転表示。
    if (hasSelection) {
      for (final (li, x1, x2) in l.selectionRects(_sel.start, _sel.end)) {
        if (li < firstVis || li > lastVis) continue;
        final sy = _oy + (li - firstVis) * lineHeight;
        final rx = _ox - (singleLine ? _scrollX : 0);
        fb.fillRectClipped(rx + x1, sy, x2 - x1, lineHeight, _ox, _clipR, on: true);
        // 選択部の文字を消灯で描き直して反転させる。
        final line = l.lines[li];
        final a = _sel.start > line.start ? _sel.start : line.start;
        final b = _sel.end < line.end ? _sel.end : line.end;
        if (a < b) {
          final seg = text.substring(a, b);
          final segX = rx + line.xs[a - line.start];
          fb.drawText(segX, sy, seg, on: false, clipLeft: _ox, clipRight: _clipR);
        }
      }
    } else if (active && caretOn) {
      // カーソル（点滅）。
      final (line, cx) = l.caretPos(_sel.extentOffset.clamp(0, text.length));
      if (line >= firstVis && line <= lastVis) {
        final sy = _oy + (line - firstVis) * lineHeight;
        final px = _ox + cx - (singleLine ? _scrollX : 0);
        if (px >= _ox && px <= _clipR) fb.vLine(px, sy, lineHeight, on: true);
      }
    }

    // 変換中（composing）の下線。
    final comp = controller.value.composing;
    if (comp.isValid && !comp.isCollapsed) {
      for (final (li, x1, x2) in l.selectionRects(comp.start, comp.end)) {
        if (li < firstVis || li > lastVis) continue;
        final sy = _oy + (li - firstVis) * lineHeight;
        final rx = _ox - (singleLine ? _scrollX : 0);
        final y0 = sy + lineHeight - 2;
        for (var xx = rx + x1; xx < rx + x2; xx++) {
          if (xx >= _ox && xx <= _clipR) fb.setPixel(xx, y0, on: true);
        }
      }
    }
  }
}
