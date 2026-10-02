import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/bdf_font.dart';
import '../engine/framebuffer.dart';
import '../engine/text_layout.dart';

// 1つの文字欄（件名=単一行 / 本文=複数行）の共通部品。
// 編集可（新規作成）/ 読み取り専用（受信メール本文）両対応。
// 正本は controller.value（TextEditingValue）。この層はスクロール位置だけ保持する。
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
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final BdfFont font;
  final int x, y, w, h, lineHeight, maxLines;
  final bool singleLine;
  final bool readOnly;

  static const int _pad = 2;

  int _scrollX = 0; // 単一行の横スクロール（px）
  int _firstLine = 0; // 複数行の先頭表示行（行単位）

  int get firstLine => _firstLine;

  int get _ox => x + _pad;
  int get _oy => y + _pad;
  int get _innerW => w - _pad * 2;
  int get _clipR => x + w - _pad - 1;

  TextLayout _layout() => TextLayout.build(
        controller.text,
        font,
        singleLine ? 1 << 20 : _innerW,
        lineHeight,
      );

  int totalLines() => _layout().lineCount;

  int get _maxFirstLine {
    final t = totalLines() - maxLines;
    return t < 0 ? 0 : t;
  }

  bool contains(int lx, int ly) =>
      lx >= x && lx < x + w && ly >= y && ly < y + h;

  TextSelection get _sel => controller.selection;

  bool get hasSelection => _sel.isValid && !_sel.isCollapsed;

  void _setValue(String text, TextSelection sel) {
    controller.value = TextEditingValue(text: text, selection: sel);
  }

  int _indexAt(int lx, int ly, TextLayout l) {
    if (singleLine) return l.indexAt(lx - _ox + _scrollX, 0);
    final li = _firstLine + ((ly - _oy) ~/ lineHeight);
    return l.indexAt(lx - _ox, (li < 0 ? 0 : li) * lineHeight);
  }

  void placeCaret(int lx, int ly) {
    if (!readOnly) focus.requestFocus();
    final l = _layout();
    final i = _indexAt(lx, ly, l);
    _setValue(controller.text, TextSelection.collapsed(offset: i));
    scrollToCaret();
  }

  void selectAt(int lx, int ly) {
    if (!readOnly) focus.requestFocus();
    final l = _layout();
    final i = _indexAt(lx, ly, l);
    final n = controller.text.length;
    _setValue(controller.text,
        TextSelection(baseOffset: i.clamp(0, n), extentOffset: (i + 1).clamp(0, n)));
    scrollToCaret();
  }

  void extendTo(int lx, int ly) {
    // 表示領域の上端/下端までドラッグしたら1行ずつ自動スクロール。
    if (!singleLine) {
      if (ly <= _oy) {
        scrollByLines(-1);
      } else if (ly >= y + h - lineHeight) {
        scrollByLines(1);
      }
    }
    final l = _layout();
    final i = _indexAt(lx, ly, l);
    _setValue(controller.text,
        TextSelection(baseOffset: _sel.baseOffset, extentOffset: i));
  }

  // ドラッグ（長押しなし）でのスクロール。dyDots 下方向が正。
  void scrollByDots(int dyDots) {
    if (singleLine) return;
    final lines = dyDots ~/ lineHeight;
    if (lines != 0) scrollByLines(-lines);
  }

  void scrollByLines(int d) {
    _firstLine = (_firstLine + d).clamp(0, _maxFirstLine);
  }

  // カーソルが表示範囲外なら、見える位置まで最小限ずらす。
  void scrollToCaret() {
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

  Future<void> copy() async {
    if (!hasSelection) return;
    await Clipboard.setData(
        ClipboardData(text: _sel.textInside(controller.text)));
  }

  Future<void> cut() async {
    if (readOnly || !hasSelection) return;
    final text = controller.text;
    final s = _sel.start, e = _sel.end;
    await Clipboard.setData(ClipboardData(text: text.substring(s, e)));
    _setValue(text.replaceRange(s, e, ''), TextSelection.collapsed(offset: s));
    scrollToCaret();
  }

  Future<void> paste() async {
    if (readOnly) return;
    final data = await Clipboard.getData('text/plain');
    final ins = data?.text ?? '';
    if (ins.isEmpty) return;
    final text = controller.text;
    final s = _sel.isValid ? _sel.start : text.length;
    final e = _sel.isValid ? _sel.end : text.length;
    final filtered = singleLine ? ins.replaceAll('\n', '') : ins;
    _setValue(text.replaceRange(s, e, filtered),
        TextSelection.collapsed(offset: s + filtered.length));
    scrollToCaret();
  }

  void selectAll() {
    final n = controller.text.length;
    if (n == 0) return;
    _setValue(controller.text, TextSelection(baseOffset: 0, extentOffset: n));
  }

  void draw(Framebuffer fb, {required bool caretOn, required bool active}) {
    final l = _layout();
    final text = controller.text;
    scrollToCaret();

    final firstVis = singleLine ? 0 : _firstLine;
    final lastVis = singleLine ? 0 : (_firstLine + maxLines - 1);

    for (var li = firstVis; li <= lastVis && li < l.lineCount; li++) {
      final line = l.lines[li];
      final sy = _oy + (li - firstVis) * lineHeight;
      final sx = _ox - (singleLine ? _scrollX : 0);
      fb.drawText(sx, sy, text.substring(line.start, line.end),
          on: true, clipLeft: _ox, clipRight: _clipR);
    }

    if (hasSelection) {
      for (final (li, x1, x2) in l.selectionRects(_sel.start, _sel.end)) {
        if (li < firstVis || li > lastVis) continue;
        final sy = _oy + (li - firstVis) * lineHeight;
        final rx = _ox - (singleLine ? _scrollX : 0);
        fb.fillRectClipped(rx + x1, sy, x2 - x1, lineHeight, _ox, _clipR,
            on: true);
        final line = l.lines[li];
        final a = _sel.start > line.start ? _sel.start : line.start;
        final b = _sel.end < line.end ? _sel.end : line.end;
        if (a < b) {
          fb.drawText(rx + line.xs[a - line.start], sy, text.substring(a, b),
              on: false, clipLeft: _ox, clipRight: _clipR);
        }
      }
    } else if (active && caretOn && !readOnly) {
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
        for (var xx = rx + x1; xx < rx + x2; xx++) {
          if (xx >= _ox && xx <= _clipR) fb.setPixel(xx, sy + lineHeight - 2, on: true);
        }
      }
    }

    // 右端の細いスクロールバー（複数行で行数が多いときだけ）。
    if (!singleLine && l.lineCount > maxLines) {
      final trackH = maxLines * lineHeight;
      final barH = (trackH * maxLines / l.lineCount).round().clamp(2, trackH);
      final barTop = _oy + (trackH * _firstLine / l.lineCount).round();
      fb.vLine(x + w - 1, barTop, barH, on: true);
    }
  }
}
