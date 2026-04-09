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

    test('stats に hp のみ指定した場合 atk=0 / def=0 でパースされる', () {
      // Arrange
      const String cardYaml = '''
      id: 'm002'
      name: 'HP Only Monster'
      type: 'monster'
      text: ''
      version: 1
      stats:
        hp: 500
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card!.stats!.hp, 500);
    });

    test('stats に hp のみ指定した場合 atk が 0 になる', () {
      const String cardYaml = '''
      id: 'm003'
      name: 'HP Only Monster'
      type: 'monster'
      text: ''
      version: 1
      stats:
        hp: 300
      ''';

      final card = CardRepository.parseCard(cardYaml);

      expect(card!.stats!.atk, 0);
    });

    test('when: on_discard は TriggerWhen.onDiscard にパースされる', () {
      // Arrange
      const String cardYaml = '''
      id: 'm004'
      name: 'Discard Monster'
      type: 'monster'
      version: 1
      stats:
        hp: 100
      abilities:
        - when: 'on_discard'
          effect:
            - op: 'draw'
              count: 1
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card!.abilities.first.when, TriggerWhen.onDiscard);
    });

    test('when: activated は TriggerWhen.activated にパースされる', () {
      // Arrange
      const String cardYaml = '''
      id: 'ar001'
      name: 'Activated Artifact'
      type: 'artifact'
      version: 1
      abilities:
        - when: 'activated'
          effect:
            - op: 'draw'
              count: 1
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card!.abilities.first.when, TriggerWhen.activated);
    });

    test('when: static（未対応値）はアビリティがスキップされ空リストになる', () {
      // Arrange
      const String cardYaml = '''
      id: 'd001'
      name: 'Static Domain'
      type: 'domain'
      version: 1
      abilities:
        - when: 'static'
          effect:
            - op: 'draw'
              count: 1
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card!.abilities, isEmpty);
    });

    test('once_per_turn: false の activated 能力は oncePerTurn が false になる', () {
      // Arrange
      const String cardYaml = '''
      id: 'ar002'
      name: 'Unlimited Artifact'
      type: 'artifact'
      version: 1
      abilities:
        - when: 'activated'
          once_per_turn: false
          effect:
            - op: 'draw'
              count: 1
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card!.abilities.first.oncePerTurn, isFalse);
    });

    test('once_per_turn を省略した activated 能力は oncePerTurn がデフォルト true になる', () {
      // Arrange
      const String cardYaml = '''
      id: 'ar003'
      name: 'Default Artifact'
      type: 'artifact'
      version: 1
      abilities:
        - when: 'activated'
          effect:
            - op: 'draw'
              count: 1
      ''';

      // Act
      final card = CardRepository.parseCard(cardYaml);

      // Assert
      expect(card!.abilities.first.oncePerTurn, isTrue);
    });

    test('when: on_spell_played は TriggerWhen.onSpellPlayed にパースされる', () {
      const String cardYaml = '''
      id: 'dmn_test'
      name: '水力発電所テスト'
      type: 'domain'
      version: 1
      abilities:
        - when: 'on_spell_played'
          once_per_turn: false
          effect:
            - op: 'add_counter'
              key: spell_count
              amount: 1
      ''';

      final card = CardRepository.parseCard(cardYaml);

      expect(card!.abilities.first.when, TriggerWhen.onSpellPlayed);
      expect(card.abilities.first.oncePerTurn, isFalse);
    });
  });
}