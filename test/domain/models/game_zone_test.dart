import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/models/game_zone.dart';

void main() {
  group('GameZone', () {
    test('removeAt returns null for negative index', () {
      // Arrange
      final zone = GameZone(type: Zone.hand);
      zone.add(CardInstance(
        card: const CardData(id: 'c1', name: 'C1', type: CardType.spell),
        instanceId: '1',
      ));

      // Act
      final removed = zone.removeAt(-1);

      // Assert
      expect(removed, isNull);
      expect(zone.count, 1);
    });

    test('removeAt returns null for out-of-bounds index', () {
      // Arrange
      final zone = GameZone(type: Zone.hand);
      zone.add(CardInstance(
        card: const CardData(id: 'c1', name: 'C1', type: CardType.spell),
        instanceId: '1',
      ));

      // Act
      final removed = zone.removeAt(1);

      // Assert
      expect(removed, isNull);
      expect(zone.count, 1);
    });

    test('removeAt successfully removes and returns a card', () {
      // Arrange
      final cardInstance = CardInstance(
        card: const CardData(id: 'c1', name: 'C1', type: CardType.spell),
        instanceId: '1',
      );
      final zone = GameZone(type: Zone.hand, cards: [cardInstance]);

      // Act
      final removed = zone.removeAt(0);

      // Assert
      expect(removed, same(cardInstance));
      expect(zone.count, 0);
    });
  });
}
