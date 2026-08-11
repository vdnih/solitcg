import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/presentation/components/board_layout.dart';

void main() {
  group('BoardLayout — カードピッチ', () {
    test('cardPitch はカード幅 + 12.0', () {
      expect(BoardLayout.cardPitch, BoardLayout.cardW + 12.0);
    });

    test('opponentCardPitch はカード幅 + 8.0', () {
      expect(BoardLayout.opponentCardPitch, BoardLayout.cardW + 8.0);
    });
  });

  group('BoardLayout — 動的値', () {
    test('plyBoardZoneWidth は画面幅からボードX座標と余白を引いた値', () {
      final size = Vector2(1000, 800);
      expect(BoardLayout.plyBoardZoneWidth(size), 1000 - BoardLayout.plyBoardX - 10);
    });

    test('oppBoardZoneWidth は画面幅からドメイン幅と余白を引いた値', () {
      final size = Vector2(1000, 800);
      expect(BoardLayout.oppBoardZoneWidth(size),
          1000 - BoardLayout.oppBoardX - (BoardLayout.domainW + 20));
    });

    test('oppDomainX は画面幅からドメイン幅と余白を引いた値', () {
      final size = Vector2(1000, 800);
      expect(BoardLayout.oppDomainX(size), 1000 - 10 - BoardLayout.domainW);
    });
  });

  group('BoardLayout — 矩形計算', () {
    test('boardRect は plyBoardX/plyFieldY を起点に plyBoardZoneWidth/fieldH のサイズを持つ', () {
      final size = Vector2(1000, 800);
      final rect = BoardLayout.boardRect(size);
      expect(rect.left, BoardLayout.plyBoardX);
      expect(rect.top, BoardLayout.plyFieldY);
      expect(rect.width, BoardLayout.plyBoardZoneWidth(size));
      expect(rect.height, BoardLayout.fieldH);
    });

    test('handRect は左右10pxの余白を持つ', () {
      final size = Vector2(1000, 800);
      final rect = BoardLayout.handRect(size);
      expect(rect.left, 10);
      expect(rect.top, BoardLayout.plyHandZoneY);
      expect(rect.width, size.x - 20);
      expect(rect.height, BoardLayout.plyHandZoneH);
    });
  });

  test('opponentAreaH は separatorY と oppHandZoneY の差', () {
    expect(BoardLayout.opponentAreaH, BoardLayout.separatorY - BoardLayout.oppHandZoneY);
  });
}
