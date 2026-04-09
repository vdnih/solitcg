import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/field_rule.dart';
import 'package:solitcg/domain/services/trigger_service.dart';

/// 魔法省カードの統合テスト。
/// spell を順次プレイし、8枚目で勝利することを検証する。

CardInstance _makeSpell(String id) {
  return CardInstance(
    card: CardData(id: id, name: id, type: CardType.spell),
    instanceId: id,
  );
}

CardInstance _makeMahou() {
  final addCounter = Ability(
    when: TriggerWhen.onSpellPlayed,
    effects: [const EffectStep(op: 'add_counter', params: {'key': 'spell_count', 'amount': 1})],
    oncePerTurn: false,
  );
  final winOnEight = Ability(
    when: TriggerWhen.onSpellPlayed,
    pre: ["self.counter('spell_count') >= 8"],
    effects: [const EffectStep(op: 'win', params: {})],
    oncePerTurn: false,
  );
  return CardInstance(
    card: CardData(
      id: 'dmn_mahou_001',
      name: '魔法省',
      type: CardType.domain,
      abilities: [addCounter, winOnEight],
    ),
    instanceId: 'mahou_inst',
  );
}

void main() {
  late GameState state;
  void noopUpdate() {}

  setUp(() {
    state = GameState();
  });

  group('魔法省 — 統合テスト', () {
    test('spell を8枚プレイすると勝利する', () async {
      final domain = _makeMahou();
      state.domain.add(domain);

      for (int i = 0; i < 8; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(state.gameWon, true);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('spell を7枚プレイしても勝利しない', () async {
      final domain = _makeMahou();
      state.domain.add(domain);

      for (int i = 0; i < 7; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(state.gameWon, false);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('spell を7枚プレイするとカウンターは 7 になる', () async {
      final domain = _makeMahou();
      state.domain.add(domain);

      for (int i = 0; i < 7; i++) {
        FieldRule.playCard(state, _makeSpell('s$i'));
        await TriggerService.resolveAll(state, noopUpdate);
      }

      expect(domain.metadata['spell_count'], 7);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('ドメインなしでスペルをプレイしても勝利しない', () async {
      FieldRule.playCard(state, _makeSpell('s0'));
      await TriggerService.resolveAll(state, noopUpdate);

      expect(state.gameWon, false);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
