import 'bdf_font.dart';

// 折り返しで分割された1視覚行。
class VisualLine {
  VisualLine(this.start, this.charCount, this.xs, this.endsWithNewline);

  /// 行の先頭文字の、文字列全体での位置（UTF-16コードユニット単位。BMP前提）。
  final int start;

  /// 本文の文字数（末尾の改行は含めない）。
  final int charCount;

  /// 文字境界のX座標。長さは charCount+1。xs[j] は j 番目の境界の左からの距離。
  final List<int> xs;

  /// この行の直後に改行（\n）があるか（ハードな行末か）。
  final bool endsWithNewline;

  int get end => start + charCount;
  int get widthPx => xs.last;
}

// フレームバッファ描画・カーソル・選択・ヒットテストで共通に使う、
// 折り返しレイアウトと「座標↔文字インデックス」変換。
class TextLayout {
  TextLayout(this.lines, this.lineHeight);

  final List<VisualLine> lines;
  final int lineHeight;

  // 文字列をレイアウトする。maxWidth を超えると折り返し、\n でも改行する。
  static TextLayout build(
    String text,
    BdfFont font,
    int maxWidth,
    int lineHeight,
  ) {
    final lines = <VisualLine>[];
    final units = text.codeUnits; // BMP前提（和文・英数はBMP）
    final n = units.length;

    var i = 0;
    var lineStart = 0;
    var curW = 0;
    final xs = <int>[0];

    void flush(bool nl) {
      lines.add(VisualLine(lineStart, xs.length - 1, List<int>.of(xs), nl));
    }

    while (i < n) {
      final cu = units[i];
      if (cu == 0x0A) {
        flush(true);
        i++;
        lineStart = i;
        curW = 0;
        xs
          ..clear()
          ..add(0);
        continue;
      }
      final w = font.glyphFor(cu)?.advance ?? 8;
      if (curW + w > maxWidth && i > lineStart) {
        flush(false);
        lineStart = i;
        curW = 0;
        xs
          ..clear()
          ..add(0);
        continue; // この文字は次の行で処理
      }
      curW += w;
      xs.add(curW);
      i++;
    }
    flush(false);
    return TextLayout(lines, lineHeight);
  }

  int get lineCount => lines.length;

  // カーソル位置（index）→ (行番号, 行内X)。
  (int, int) caretPos(int index) {
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      if (index < line.start) continue;
      if (index < line.end) {
        return (li, line.xs[index - line.start]);
      }
      if (index == line.end) {
        // 行末。改行付き、または最終行なら、この行の末尾に置く。
        if (line.endsWithNewline || li == lines.length - 1) {
          return (li, line.xs[line.charCount]);
        }
        // ソフト折り返しの境界は、次の行の先頭に置く。
        continue;
      }
    }
    final last = lines.last;
    return (lines.length - 1, last.xs[last.charCount]);
  }

  // (行内X, 行番号) ではなく、画面上のローカル座標から index を求める。
  // py は行高で割って行番号にする。
  int indexAt(int px, int py) {
    var li = py ~/ lineHeight;
    if (li < 0) li = 0;
    if (li >= lines.length) li = lines.length - 1;
    final line = lines[li];
    // 最も近い文字境界を選ぶ。
    var best = 0;
    var bestDist = (px - line.xs[0]).abs();
    for (var j = 1; j <= line.charCount; j++) {
      final d = (px - line.xs[j]).abs();
      if (d < bestDist) {
        bestDist = d;
        best = j;
      }
    }
    return line.start + best;
  }

  // 選択範囲 [a,b) を、行ごとの (行番号, x1, x2) に分解する。
  List<(int, int, int)> selectionRects(int a, int b) {
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    final rects = <(int, int, int)>[];
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final s = a > line.start ? a : line.start;
      final e = b < line.end ? b : line.end;
      if (s < e) {
        rects.add((li, line.xs[s - line.start], line.xs[e - line.start]));
      }
    }
    return rects;
  }
}
