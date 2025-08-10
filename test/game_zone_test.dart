import 'package:flutter_test/flutter_test.dart';
import '../lib/engine/types.dart';

void main() {
  group('GameZone', () {
    test('removeAt returns null for negative index', () {
      final zone = GameZone(type: Zone.hand);
      zone.add(CardInstance(
        card: Card(id: 'c1', name: 'C1', type: CardType.spell),
        instanceId: '1',
      ));

      final removed = zone.removeAt(-1);

      expect(removed, isNull);
      expect(zone.count, 1);
    });
  });
}
