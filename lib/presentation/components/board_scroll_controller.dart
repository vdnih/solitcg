import 'package:flame/components.dart';

import 'board_layout.dart';

/// `BoardComponent` の縦スクロール（盤面全体）・横スクロール（手札・ボード）・
/// 相手エリア表示トグルの状態とクランプ処理をまとめて管理する。
///
/// `_opponentAreaOffset`/`effectiveScrollY` の挙動は過去の不具合修正
/// （相手エリアトグル・リサイズ時のスクロール位置ズレ）で調整された
/// デリケートな計算のため、ロジックは変更せずそのまま移設している。
class BoardScrollController {
  double viewScrollY = 0.0;
  double handScrollX = 0.0;
  double boardScrollX = 0.0;

  bool _opponentAreaVisible = true;
  // _viewScrollY と独立した固定オフセット。
  // 画面が大きい場合でもクランプに消されず確実にシフトする。
  double _opponentAreaOffset = 0.0;

  bool get opponentAreaVisible => _opponentAreaVisible;

  /// 相手エリアの表示/非表示を切り替える。HUDは常に表示され、
  /// 非表示時は手札・フィールド分だけ固定オフセットで上へシフトする。
  void setOpponentAreaVisible(bool value, Vector2 size) {
    if (_opponentAreaVisible == value) return;
    _opponentAreaVisible = value;
    _opponentAreaOffset = value ? 0.0 : -BoardLayout.opponentAreaH;
    clampViewScrollY(size);
  }

  /// 描画・当たり判定に使う実効スクロール量（ユーザースクロール + 固定オフセット）
  double get effectiveScrollY => viewScrollY + _opponentAreaOffset;

  /// 画面サイズに応じて縦スクロール位置を有効範囲にクランプする。
  void clampViewScrollY(Vector2 size) {
    final effectiveH = _opponentAreaVisible
        ? BoardLayout.totalContentH
        : BoardLayout.totalContentH - BoardLayout.opponentAreaH;
    final minScrollY = (size.y - effectiveH).clamp(-double.infinity, 0.0);
    viewScrollY = viewScrollY.clamp(minScrollY, 0.0);
  }

  /// 縦スクロール初期位置を設定する。
  /// 画面が小さい場合はプレイヤーHUDが見える位置から開始する。
  void initViewScrollY(Vector2 size) {
    viewScrollY =
        (size.y - BoardLayout.totalContentH).clamp(-double.infinity, 0.0);
    clampViewScrollY(size);
  }

  /// 横スクロール量を、コンテンツ全幅とゾーン幅から算出したオーバーフロー分だけ
  /// 許容してクランプする（手札・ボードの横スクロールで共通の計算）。
  static double clampHorizontalOverflow(
      double current, double totalContentWidth, double zoneWidth) {
    final overflow = totalContentWidth - zoneWidth;
    final minScroll = overflow > 0 ? -overflow : 0.0;
    return current.clamp(minScroll, 0.0);
  }
}
