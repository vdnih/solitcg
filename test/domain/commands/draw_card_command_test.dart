import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/commands/draw_card_command.dart';

void main() {
  group('DrawCardCommand', () {
    late GameState gameState;
    late CardData cardA;
    late CardData cardB;

    setUp(() {
      // Arrange: 各テストの前に状態を初期化
      gameState = GameState();
      cardA = const CardData(id: 'A', name: 'Card A', type: CardType.monster);
      cardB = const CardData(id: 'B', name: 'Card B', type: CardType.spell);
    });

    test('デッキが2枚の時に1枚ドローすると、手札が1枚増え、デッキが1枚になる', () {
      // Arrange: テスト固有の状態設定
      gameState.deck.cards.clear();
      gameState.deck.cards.addAll([
        CardInstance(card: cardA, instanceId: 'a1'),
        CardInstance(card: cardB, instanceId: 'b1'),
      ]);
      gameState.hand.cards.clear();
      final command = DrawCardCommand(count: 1);

      // Act: コマンドを実行
      command.execute(gameState);

      // Assert: 結果を検証
      expect(gameState.hand.count, 1);
      expect(gameState.hand.cards[0].card.id, 'A');
      expect(gameState.deck.count, 1);
    });

    test('デッキが1枚の時に2枚ドローしようとすると、1枚だけドローされる', () {
      // Arrange
      gameState.deck.cards.clear();
      gameState.deck.cards.add(CardInstance(card: cardA, instanceId: 'a1'));
      gameState.hand.cards.clear();
      final command = DrawCardCommand(count: 2);

      // Act
      command.execute(gameState);

      // Assert
      expect(gameState.hand.count, 1);
      expect(gameState.deck.count, 0);
    });

    test('デッキが0枚の時にドローしても、手札もデッキも0枚のまま', () {
      // Arrange
      gameState.deck.cards.clear();
      gameState.hand.cards.clear();
      final command = DrawCardCommand(count: 1);

      // Act
      command.execute(gameState);

      // Assert
      expect(gameState.hand.count, 0);
      expect(gameState.deck.count, 0);
    });
  });
}