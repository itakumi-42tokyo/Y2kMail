import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'palette.dart';

// 表示パネルの見せ方を差し替え可能にするためのインターフェース。
// フレームバッファ（各画素の明るさ）を受け取り、画面に描く。
abstract class PanelRenderer {
  Color get background;

  /// スプライトの内部解像度（高解像度で作って縮小配置する）。
  int get spriteSize;

  /// スプライトを用意する（内部解像度は spriteSize で固定）。
  Future<void> prepare();

  /// 用意済みか。
  bool get ready;

  /// 1コマ描画する。[transforms] はセルごとの配置（長さ=画素数）。
  /// [pixels] は各画素のパレット番号。
  void paintPanel(
    Canvas canvas,
    List<RSTransform> transforms,
    Uint8List pixels,
  );
}

// 現行パネル: 丸型電球のLED電光掲示板ふう。
// 点灯/消灯のスプライトを事前生成し、drawAtlas でまとめて描く。
class BulbPanelRenderer implements PanelRenderer {
  ui.Image? _atlas; // 左: 消灯 / 右: 点灯

  // 高解像度でスプライトを作り、各セルへ縮小配置する（円・光をきれいに出すため）。
  static const int _spr = 48;

  @override
  int get spriteSize => _spr;

  @override
  Color get background => Palette.background;

  @override
  bool get ready => _atlas != null;

  @override
  Future<void> prepare() async {
    if (_atlas != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintOff(canvas, const Offset(_spr / 2, _spr / 2));
    _paintLit(canvas, const Offset(_spr + _spr / 2, _spr / 2));
    _atlas = await recorder.endRecording().toImage(_spr * 2, _spr);
  }

  void _paintOff(Canvas canvas, Offset c) {
    // 直径はセルの85%。
    final r = _spr * 0.85 / 2;
    canvas.drawCircle(c, r, Paint()..color = Palette.bulbOff);
  }

  void _paintLit(Canvas canvas, Offset c) {
    final r = _spr * 0.85 / 2;
    // 外側のにじむ光（半径1.4倍・不透明度20%程度）。
    canvas.drawCircle(c, r * 1.4, Paint()..color = Palette.litGlow);
    // 電球本体（中心→60%→縁の放射状グラデーション）。
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [Palette.litCenter, Palette.litMid, Palette.litEdge],
          [0.0, 0.6, 1.0],
        ),
    );
  }

  @override
  void paintPanel(
    Canvas canvas,
    List<RSTransform> transforms,
    Uint8List pixels,
  ) {
    canvas.drawColor(background, BlendMode.src);
    final atlas = _atlas;
    if (atlas == null) return;

    final offRect = Rect.fromLTWH(0, 0, _spr.toDouble(), _spr.toDouble());
    final litRect =
        Rect.fromLTWH(_spr.toDouble(), 0, _spr.toDouble(), _spr.toDouble());

    // パレット番号で、点灯/消灯スプライトを選ぶ（0=消灯, それ以外=点灯）。
    final rects = List<Rect>.generate(
      pixels.length,
      (i) => pixels[i] != 0 ? litRect : offRect,
      growable: false,
    );

    // 縮小してもなめらかに（電球は丸いアナログ形状なので補間してよい）。
    canvas.drawAtlas(
      atlas,
      transforms,
      rects,
      null,
      BlendMode.srcOver,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
