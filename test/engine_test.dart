import 'package:flutter_test/flutter_test.dart';
import '../lib/engine/types.dart';
import '../lib/engine/field_rule.dart';
import '../lib/engine/stack.dart';
import '../lib/engine/ops.dart';

void main() {
  group('Field Replacement Tests', () {
    test('Field replacement triggers new on_play then old on_destroy', () {
      final state = GameState();
      
      final field1 = Card(
        id: 'field1',
        name: 'Field 1',
        type: CardType.field,
        abilities: [
          Ability(
            when: TriggerWhen.onPlay,
            effects: [EffectStep(op: 'draw', params: {'count': 1})],
          ),
          Ability(
            when: TriggerWhen.onDestroy,
            effects: [EffectStep(op: 'draw', params: {'count': 2})],
          ),
        ],
      );
      
      final field2 = Card(
        id: 'field2',
        name: 'Field 2',
        type: CardType.field,
        abilities: [
          Ability(
            when: TriggerWhen.onPlay,
            effects: [EffectStep(op: 'draw', params: {'count': 3})],
          ),
        ],
      );

      final instance1 = CardInstance(
        card: field1,
        instanceId: state.generateInstanceId(),
      );
      
      final instance2 = CardInstance(
        card: field2,
        instanceId: state.generateInstanceId(),
      );

      for (int i = 0; i < 10; i++) {
        state.deck.add(CardInstance(
          card: Card(id: 'dummy$i', name: 'Dummy $i', type: CardType.spell),
          instanceId: state.generateInstanceId(),
        ));
      }

      FieldRule.playField(state, instance1);
      TriggerStack.resolveAll(state);

      expect(state.hand.count, 1);
      expect(state.field.first?.card.id, 'field1');

      FieldRule.playField(state, instance2);
      final logs = TriggerStack.resolveAll(state).logs;

      expect(state.hand.count, 6);
      expect(state.field.first?.card.id, 'field2');
      expect(state.grave.count, 1);
      
      expect(logs.any((log) => log.contains('Field 2')), true);
      expect(logs.any((log) => log.contains('Field 1')), true);
    });
  });

  group('FIFO Queue Tests', () {
    test('Triggers resolve in FIFO order', () {
      final state = GameState();
      final logs = <String>[];
      
      final card1 = CardInstance(
        card: Card(
          id: 'card1',
          name: 'Card 1',
          type: CardType.spell,
          abilities: [
            Ability(
              when: TriggerWhen.onPlay,
              effects: [EffectStep(op: 'draw', params: {'count': 1})],
            ),
          ],
        ),
        instanceId: state.generateInstanceId(),
      );
      
      final card2 = CardInstance(
        card: Card(
          id: 'card2', 
          name: 'Card 2',
          type: CardType.spell,
          abilities: [
            Ability(
              when: TriggerWhen.onPlay,
              effects: [EffectStep(op: 'draw', params: {'count': 1})],
            ),
          ],
        ),
        instanceId: state.generateInstanceId(),
      );

      for (int i = 0; i < 10; i++) {
        state.deck.add(CardInstance(
          card: Card(id: 'dummy$i', name: 'Dummy $i', type: CardType.spell),
          instanceId: state.generateInstanceId(),
        ));
      }

      TriggerStack.enqueueAbility(state, card1, card1.card.abilities[0]);
      TriggerStack.enqueueAbility(state, card2, card2.card.abilities[0]);
      
      final result = TriggerStack.resolveAll(state);
      
      final triggerLogs = result.logs.where((log) => log.startsWith('Resolving:')).toList();
      expect(triggerLogs[0], contains('Card 1'));
      expect(triggerLogs[1], contains('Card 2'));
      expect(state.hand.count, 2);
    });
  });

  group('Require Failure Tests', () {
    test('Require failure stops execution', () {
      final state = GameState();
      
      final card = CardInstance(
        card: Card(
          id: 'test',
          name: 'Test Card',
          type: CardType.spell,
          abilities: [
            Ability(
              when: TriggerWhen.onPlay,
              effects: [
                EffectStep(op: 'require', params: {'expr': 'hand.count >= 1'}),
                EffectStep(op: 'discard', params: {'from': 'hand', 'count': 1}),
                EffectStep(op: 'draw', params: {'count': 2}),
              ],
            ),
          ],
        ),
        instanceId: state.generateInstanceId(),
      );

      TriggerStack.enqueueAbility(state, card, card.card.abilities[0]);
      final result = TriggerStack.resolveAll(state);
      
      expect(result.success, false);
      expect(result.logs.any((log) => log.contains('Requirement not met')), true);
      expect(state.hand.count, 0);
      expect(state.grave.count, 0);
    });

    test('Require success allows execution', () {
      final state = GameState();
      
      state.hand.add(CardInstance(
        card: Card(id: 'dummy', name: 'Dummy', type: CardType.spell),
        instanceId: state.generateInstanceId(),
      ));
      
      for (int i = 0; i < 5; i++) {
        state.deck.add(CardInstance(
          card: Card(id: 'deck$i', name: 'Deck $i', type: CardType.spell),
          instanceId: state.generateInstanceId(),
        ));
      }

      final card = CardInstance(
        card: Card(
          id: 'test',
          name: 'Test Card',
          type: CardType.spell,
          abilities: [
            Ability(
              when: TriggerWhen.onPlay,
              effects: [
                EffectStep(op: 'require', params: {'expr': 'hand.count >= 1'}),
                EffectStep(op: 'discard', params: {'from': 'hand', 'count': 1}),
                EffectStep(op: 'draw', params: {'count': 2}),
              ],
            ),
          ],
        ),
        instanceId: state.generateInstanceId(),
      );

      TriggerStack.enqueueAbility(state, card, card.card.abilities[0]);
      final result = TriggerStack.resolveAll(state);
      
      expect(result.success, true);
      expect(state.hand.count, 2);
      expect(state.grave.count, 1);
    });
  });
}