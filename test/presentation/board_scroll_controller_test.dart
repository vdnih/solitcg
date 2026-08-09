import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/presentation/components/board_layout.dart';
import 'package:solitcg/presentation/components/board_scroll_controller.dart';

void main() {
  group('BoardScrollController — 縦スクロールのクランプ', () {
    test('コンテンツが画面より小さい場合はスクロールできない（0に固定）', () {
      final controller = BoardScrollController();
      final size = Vector2(1000, BoardLayout.totalContentH + 200);

      controller.viewScrollY = -999;
      controller.clampViewScrollY(size);

      expect(controller.viewScrollY, 0.0);
    });

    test('コンテンツが画面より大きい場合は overflow 分だけ上にスクロールできる', () {
      final controller = BoardScrollController();
      final size = Vector2(1000, BoardLayout.totalContentH - 100);

      controller.viewScrollY = -999;
      controller.clampViewScrollY(size);

      expect(controller.viewScrollY, -100);
    });

    test('initViewScrollY は画面が小さい場合、プレイヤーHUDが見える位置から開始する', () {
      final controller = BoardScrollController();
      final size = Vector2(1000, BoardLayout.totalContentH - 50);

      controller.initViewScrollY(size);

      expect(controller.viewScrollY, -50);
    });
  });

  group('BoardScrollController — 相手エリア表示トグル', () {
    test('非表示にすると effectiveScrollY が opponentAreaH 分だけ上にシフトする', () {
      final controller = BoardScrollController();
      final size = Vector2(1000, BoardLayout.totalContentH + 500);

      controller.setOpponentAreaVisible(false, size);

      expect(controller.effectiveScrollY, -BoardLayout.opponentAreaH);
    });

    test('再表示するとオフセットが解除される', () {
      final controller = BoardScrollController();
      final size = Vector2(1000, BoardLayout.totalContentH + 500);

      controller.setOpponentAreaVisible(false, size);
      controller.setOpponentAreaVisible(true, size);

      expect(controller.effectiveScrollY, 0.0);
    });

    test('同じ値を設定しても状態は変化しない', () {
      final controller = BoardScrollController();
      final size = Vector2(1000, BoardLayout.totalContentH + 500);

      controller.setOpponentAreaVisible(true, size);

      expect(controller.opponentAreaVisible, isTrue);
      expect(controller.effectiveScrollY, 0.0);
    });
  });

  group('BoardScrollController.clampHorizontalOverflow', () {
    test('コンテンツがゾーンより狭い場合は 0 にクランプされる', () {
      final result = BoardScrollController.clampHorizontalOverflow(-999, 200, 500);
      expect(result, 0.0);
    });

    test('コンテンツがゾーンより広い場合は overflow 分だけ負方向に許容される', () {
      final result = BoardScrollController.clampHorizontalOverflow(-999, 700, 500);
      expect(result, -200);
    });

    test('現在値が範囲内ならそのまま返す', () {
      final result = BoardScrollController.clampHorizontalOverflow(-50, 700, 500);
      expect(result, -50);
    });
  });
}
