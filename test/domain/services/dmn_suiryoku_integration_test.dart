import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/field_rule.dart';
import 'package:solitcg/domain/services/trigger_service.dart';

/// 水力発電所カードの統合テスト。
/// spell を順次プレイし、4枚目でカードを1枚引くことを検証する。

CardInstance _makeSpell(String id) {
  return CardInstance(
    card: CardData(id: id, name: id, type: CardType.spell),
    instanceId: id,
  );
}

CardInstance _makeSuiryoku() {
  final addCounter = Ability(
    when: TriggerWhen.onSpellPlayed,
    effects: [const EffectStep(op: 'add_counter', params: {'key': 'spell_count', 'amount': 1})],
    oncePerTurn: false,
  );
  final drawOnFour = Ability(
    when: TriggerWhen.onSpellPlayed,
    pre: ["self.counter('spell_count') >= 4"],
    effects: [
      const EffectStep(op: 'remove_counter', params: {'key': 'spell_count'}),
      const EffectStep(op: 'draw', params: {'count': 1}),
    ],
    oncePerTurn: false,
  );
  return CardInstance(
    card: CardData(
      id: 'dmn_suiryoku_001',
      name: '水力発電所',
      type: CardType.domain,
      abilities: [addCounter, drawOnFour],
    ),
    instanceId: 'suiryoku_inst',
  );
}

void main() {
  late GameState state;
  void noopUpdate() {}

  setUp(() {
    state = GameState();
  });

  group('水力発電所 — 統合テスト', () {
    test('spell を4枚プレイするとカードを1枚引く', () async {
      final domain = _makeSuiryoku();
      state.domain.add(domain);
      state.deck.add(_makeSpell('deck_card'));

      for (int i = 0; i < 4; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(state.hand.count, 1);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('spell を4枚プレイするとカウンターが 0 にリセットされる', () async {
      final domain = _makeSuiryoku();
      state.domain.add(domain);
      state.deck.add(_makeSpell('deck_card'));

      for (int i = 0; i < 4; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(domain.metadata['spell_count'], 0);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('spell を3枚プレイしても手札は増えない', () async {
      final domain = _makeSuiryoku();
      state.domain.add(domain);

      for (int i = 0; i < 3; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(state.hand.count, 0);
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('spell を3枚プレイするとカウンターは 3 になる', () async {
      final domain = _makeSuiryoku();
      state.domain.add(domain);

      for (int i = 0; i < 3; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(domain.metadata['spell_count'], 3);
    }, timeout: const Timeout(Duration(seconds: 25)));
  });
}
