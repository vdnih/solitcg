import 'package:flame/components.dart';
import 'package:flutter/material.dart' as material;

/// ボード盤面のレイアウト定数と、そこから導出される矩形計算をまとめたクラス。
///
/// `BoardComponent` の描画・当たり判定・スクロールクランプが参照する
/// 座標値を一元管理し、`board_component.dart` 内での重複計算を排除する。
class BoardLayout {
  BoardLayout._();

  // ─── 相手エリア（上） ─────────────────────────────────────────
  static const double oppHudY = 5.0;
  static const double oppHandZoneY = 30.0;
  static const double oppHandZoneH = 155.0;
  static const double oppFieldY = 190.0;
  static const double fieldH = 165.0;

  // ─── セパレーター ─────────────────────────────────────────────
  static const double separatorY = 360.0;

  // ─── 自分エリア（下） ─────────────────────────────────────────
  static const double plyFieldY = 366.0;
  static const double plyHandZoneY = 536.0;
  static const double plyHandZoneH = 155.0;
  static const double plyHudY = 695.0;

  // ─── カードサイズ・並び間隔 ─────────────────────────────────────
  static const double cardW = 100.0;
  static const double cardH = 140.0;
  static const double _cardGapX = 12.0;
  static const double _opponentCardGapX = 8.0;

  /// 手札・ボードカードの横方向の並び間隔（カード幅 + 余白）
  static const double cardPitch = cardW + _cardGapX; // 112.0
  /// 相手の裏向き手札カードの並び間隔（自分の手札より詰めて表示）
  static const double opponentCardPitch = cardW + _opponentCardGapX; // 108.0

  // ─── ドメインゾーン幅 ───────────────────────────────────────────
  static const double domainW = 120.0;

  // 自分: ドメイン左・ボード右
  static const double plyDomainX = 10.0;
  static const double plyBoardX = 140.0;

  // 相手: ドメイン右・ボード左（点対称）
  static const double oppBoardX = 10.0;

  // ─── 縦スクロール用コンテンツ全高 ─────────────────────────────
  static const double totalContentH = 725.0;
  /// 相手の手札・フィールドゾーン高さ（HUDを除いた部分）
  static const double opponentAreaH = separatorY - oppHandZoneY; // 330.0

  // ─── 画面幅に依存する動的値 ─────────────────────────────────────
  static double plyBoardZoneWidth(Vector2 size) => size.x - plyBoardX - 10;
  static double oppBoardZoneWidth(Vector2 size) =>
      size.x - oppBoardX - (domainW + 20);
  static double oppDomainX(Vector2 size) => size.x - 10 - domainW;

  /// 自分フィールドのボードエリア矩形（スクロールオフセット適用前のローカル座標）
  static material.Rect boardRect(Vector2 size) => material.Rect.fromLTWH(
      plyBoardX, plyFieldY, plyBoardZoneWidth(size), fieldH);

  /// 自分手札エリア矩形（スクロールオフセット適用前のローカル座標）
  static material.Rect handRect(Vector2 size) =>
      material.Rect.fromLTWH(10, plyHandZoneY, size.x - 20, plyHandZoneH);
}
