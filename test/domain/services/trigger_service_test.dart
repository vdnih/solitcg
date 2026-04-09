import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/trigger_service.dart';

// resolveAll は内部で await Future.delayed(1s) を含むため、
// 各テストは最小限のトリガー数（1〜2件）に絞る。

CardInstance _makeCard(String id, CardType type) {
  return CardInstance(
    card: CardData(id: id, name: id, type: type),
    instanceId: id,
  );
}

Ability _makeWinAbility() {
  return Ability(
    when: TriggerWhen.onPlay,
    effects: [const EffectStep(op: 'win', params: {})],
  );
}

Ability _makeWinAbilityWithPre(String preExpr) {
  return Ability(
    when: TriggerWhen.onPlay,
    pre: [preExpr],
    effects: [const EffectStep(op: 'win', params: {})],
  );
}

void main() {
  late GameState state;
  void noopUpdate() {}

  setUp(() {
    state = GameState();
  });

  // ----------------------------------------------------------------
  group('TriggerService.enqueueAbility', () {
    test('エンキュー後 triggerQueue の長さが 1 になる', () {
      final card = _makeCard('c1', CardType.spell);
      final ability = Ability(when: TriggerWhen.onPlay, effects: const []);

      TriggerService.enqueueAbility(state, card, ability);

      expect(state.triggerQueue.length, 1);
    });

    test('2回エンキューすると triggerQueue の長さが 2 になる', () {
      final card = _makeCard('c1', CardType.spell);
      final ability = Ability(when: TriggerWhen.onPlay, effects: const []);

      TriggerService.enqueueAbility(state, card, ability);
      TriggerService.enqueueAbility(state, card, ability);

      expect(state.triggerQueue.length, 2);
    });
  });

  // ----------------------------------------------------------------
  group('TriggerService.resolveAll — pre 条件', () {
    test('pre 条件が満たされる場合 effect が実行される', () async {
      for (int i = 0; i < 7; i++) {
        state.hand.add(_makeCard('h$i', CardType.spell));
      }
      final card = _makeCard('c1', CardType.spell);
      final ability = _makeWinAbilityWithPre('hand.count >= 7');

      TriggerService.enqueueAbility(state, card, ability);
      await TriggerService.resolveAll(state, noopUpdate);

      expect(state.gameWon, isTrue);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('pre 条件が満たされない場合 effect がスキップされる', () async {
      final card = _makeCard('c1', CardType.spell);
      final ability = _makeWinAbilityWithPre('hand.count >= 7');

      TriggerService.enqueueAbility(state, card, ability);
      await TriggerService.resolveAll(state, noopUpdate);

      expect(state.gameWon, isFalse);
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  // ----------------------------------------------------------------
  group('TriggerService.resolveAll — FIFO 順序', () {
    test('先にエンキューしたトリガーのログが先に記録される', () async {
      final card1 = _makeCard('c1', CardType.spell);
      final card2 = _makeCard('c2', CardType.spell);
      final ability1 = Ability(when: TriggerWhen.onPlay, effects: const []);
      final ability2 = Ability(when: TriggerWhen.onPlay, effects: const []);

      TriggerService.enqueueAbility(state, card1, ability1);
      TriggerService.enqueueAbility(state, card2, ability2);

      final result = await TriggerService.resolveAll(state, noopUpdate);

      // FIFO: c1 が c2 より先にログに現れる
      final resolvingLogs = result.logs.where((l) => l.contains('Resolving:')).toList();
      expect(resolvingLogs.first, contains('c1'));
      expect(resolvingLogs.last, contains('c2'));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  // ----------------------------------------------------------------
  group('TriggerService.resolveAll — キューが空', () {
    test('キューが空の場合は即座に success を返す', () async {
      final result = await TriggerService.resolveAll(state, noopUpdate);

      expect(result.success, isTrue);
    }, timeout: const Timeout(Duration(seconds: 3)));
  });

  // ----------------------------------------------------------------
  group('TriggerService.resolveAll — awaitingChoice 伝播', () {
    test('discard selection=choose でプレイヤー選択待ちになると pending を返す', () async {
      // 手札3枚、2枚選んで捨てる(selection=choose) → ChoiceUI待ち
      state.hand.add(CardInstance(
        card: CardData(id: 'h1', name: 'h1', type: CardType.spell),
        instanceId: 'h1',
      ));
      state.hand.add(CardInstance(
        card: CardData(id: 'h2', name: 'h2', type: CardType.spell),
        instanceId: 'h2',
      ));
      state.hand.add(CardInstance(
        card: CardData(id: 'h3', name: 'h3', type: CardType.spell),
        instanceId: 'h3',
      ));

      final card = _makeCard('src', CardType.spell);
      final ability = Ability(
        when: TriggerWhen.onPlay,
        effects: const [
          EffectStep(op: 'discard', params: {'from': 'hand', 'count': 2, 'selection': 'choose'}),
        ],
      );

      TriggerService.enqueueAbility(state, card, ability);
      final result = await TriggerService.resolveAll(state, noopUpdate);

      expect(result.awaitingChoice, isTrue);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('awaitingChoice 時に choiceRequest がセットされる', () async {
      state.hand.add(CardInstance(
        card: CardData(id: 'h1', name: 'h1', type: CardType.spell),
        instanceId: 'h1',
      ));
      state.hand.add(CardInstance(
        card: CardData(id: 'h2', name: 'h2', type: CardType.spell),
        instanceId: 'h2',
      ));
      state.hand.add(CardInstance(
        card: CardData(id: 'h3', name: 'h3', type: CardType.spell),
        instanceId: 'h3',
      ));

      final card = _makeCard('src', CardType.spell);
      final ability = Ability(
        when: TriggerWhen.onPlay,
        effects: const [
          EffectStep(op: 'discard', params: {'from': 'hand', 'count': 2, 'selection': 'choose'}),
        ],
      );

      TriggerService.enqueueAbility(state, card, ability);
      await TriggerService.resolveAll(state, noopUpdate);

      expect(state.choiceRequest.value, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('選択後に続く effect が choiceRequest.pendingEffects に格納される', () async {
      // 手札3枚、1枚捨てる→墓地から1枚回収（連続選択）
      state.hand.add(CardInstance(
        card: CardData(id: 'h1', name: 'h1', type: CardType.spell),
        instanceId: 'h1',
      ));
      state.hand.add(CardInstance(
        card: CardData(id: 'h2', name: 'h2', type: CardType.spell),
        instanceId: 'h2',
      ));
      state.grave.add(CardInstance(
        card: CardData(id: 'g1', name: 'g1', type: CardType.spell),
        instanceId: 'g1',
      ));
      state.grave.add(CardInstance(
        card: CardData(id: 'g2', name: 'g2', type: CardType.spell),
        instanceId: 'g2',
      ));

      final card = _makeCard('src', CardType.artifact);
      final ability = Ability(
        when: TriggerWhen.activated,
        effects: const [
          EffectStep(op: 'discard', params: {'from': 'hand', 'count': 1, 'selection': 'choose'}),
          EffectStep(op: 'move', params: {'from': 'grave', 'to': 'hand', 'count': 1, 'selection': 'choose'}),
        ],
      );

      TriggerService.enqueueAbility(state, card, ability);
      await TriggerService.resolveAll(state, noopUpdate);

      // 最初の discard 選択待ち中に、move effect が pendingEffects に格納される
      expect(state.choiceRequest.value?.pendingEffects.length, 1);
      expect(state.choiceRequest.value?.pendingEffects.first.op, 'move');
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
