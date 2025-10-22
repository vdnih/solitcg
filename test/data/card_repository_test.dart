import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/data/repositories/card_repository.dart';
import 'package:solitcg/domain/models/card_data.dart';

void main() {
  group('CardRepository.parseCard', () {
    test('should correctly parse a valid monster card YAML', () {
      // Arrange
      const String cardYaml = '''
      id: 'c001'
      name: 'Test Monster'
      type: 'monster'
      text: 'A test monster.'
      stats:
        atk: 100
        def: 200
        hp: 300
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card, isNotNull);
      expect(card, isA<CardData>());
      expect(card!.id, 'c001');
      expect(card.name, 'Test Monster');
      expect(card.type, CardType.monster);
      expect(card.text, 'A test monster.');
      expect(card.stats, isNotNull);
      expect(card.stats!.atk, 100);
      expect(card.stats!.def, 200);
      expect(card.stats!.hp, 300);
    });

    test('should correctly parse a valid spell card with abilities', () {
      // Arrange
      const String cardYaml = '''
      id: 's001'
      name: 'Test Spell'
      type: 'spell'
      abilities:
        - when: 'on_play'
          priority: 1
          effect:
            - op: 'draw'
              count: 2
            - op: 'require'
              expr: 'hand.count >= 1'
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card, isNotNull);
      expect(card!.id, 's001');
      expect(card.name, 'Test Spell');
      expect(card.type, CardType.spell);
      expect(card.abilities, isNotEmpty);
      expect(card.abilities.length, 1);
      final ability = card.abilities.first;
      expect(ability.when, TriggerWhen.onPlay);
      expect(ability.priority, 1);
      expect(ability.effects.length, 2);
      expect(ability.effects[0].op, 'draw');
      expect(ability.effects[0].params['count'], 2);
      expect(ability.effects[1].op, 'require');
    });

    test('should return null for invalid YAML', () {
      // Arrange
      const String invalidYaml = 'id: c001\nname: Test\ntype: monster\n  stats: atk: 100'; // malformed yaml

      // Act
      final card = CardRepository.parseCard(invalidYaml);

      // Assert
      expect(card, isNull);
    });

    test('should return null for missing required fields', () {
      // Arrange
      const String incompleteYaml = 'id: c001\nname: Test'; // missing type

      // Act
      final card = CardRepository.parseCard(incompleteYaml);

      // Assert
      expect(card, isNull);
    });
  });
}