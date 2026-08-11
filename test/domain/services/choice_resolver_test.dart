import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/models/choice_request.dart';
import 'package:solitcg/domain/services/choice_resolver.dart';

CardInstance _makeCard(String id, CardType type) {
  return CardInstance(
    card: CardData(id: id, name: id, type: type),
    instanceId: id,
  );
}

void main() {
  late GameState state;

  setUp(() {
    state = GameState();
  });

  group('ChoiceResolver.applySelection — choiceRequest が null', () {
    test('何もせず success を返す', () {
      final result = ChoiceResolver.applySelection(state, []);
      expect(result.success, isTrue);
    });
  });

  group('ChoiceResolver.applySelection — discard', () {
    test('選択したカードが手札から墓地に移動する', () {
      final c1 = _makeCard('h1', CardType.spell);
      final c2 = _makeCard('h2', CardType.spell);
      state.hand.add(c1);
      state.hand.add(c2);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: 1,
        candidates: [c1, c2],
        sourceZone: 'hand',
      );

      ChoiceResolver.applySelection(state, [c1]);

      expect(state.hand.cards, [c2]);
      expect(state.grave.cards, [c1]);
    });

    test('解決後 choiceRequest がクリアされる', () {
      final c1 = _makeCard('h1', CardType.spell);
      state.hand.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: 1,
        candidates: [c1],
        sourceZone: 'hand',
      );

      ChoiceResolver.applySelection(state, [c1]);

      expect(state.choiceRequest.value, isNull);
    });

    test('onDiscard アビリティがトリガーキューに積まれる', () {
      final ability = Ability(when: TriggerWhen.onDiscard, effects: const []);
      final c1 = CardInstance(
        card: CardData(id: 'h1', name: 'h1', type: CardType.spell, abilities: [ability]),
        instanceId: 'h1',
      );
      state.hand.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: 1,
        candidates: [c1],
        sourceZone: 'hand',
      );

      ChoiceResolver.applySelection(state, [c1]);

      expect(state.triggerQueue.length, 1);
    });
  });

  group('ChoiceResolver.applySelection — move', () {
    test('選択したカードが sourceZone から targetZone に移動する', () {
      final c1 = _makeCard('g1', CardType.spell);
      state.grave.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.move,
        count: 1,
        candidates: [c1],
        sourceZone: 'grave',
        targetZone: 'hand',
      );

      ChoiceResolver.applySelection(state, [c1]);

      expect(state.grave.isEmpty, isTrue);
      expect(state.hand.cards, [c1]);
    });
  });

  group('ChoiceResolver.applySelection — destroy', () {
    test('選択したカードが盤面から墓地に移動する', () {
      final c1 = _makeCard('b1', CardType.monster);
      state.board.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.destroy,
        count: 1,
        candidates: [c1],
        sourceZone: 'board',
      );

      ChoiceResolver.applySelection(state, [c1]);

      expect(state.board.isEmpty, isTrue);
      expect(state.grave.cards, [c1]);
    });

    test('onDestroy アビリティがトリガーキューに積まれる', () {
      final ability = Ability(when: TriggerWhen.onDestroy, effects: const []);
      final c1 = CardInstance(
        card: CardData(id: 'b1', name: 'b1', type: CardType.monster, abilities: [ability]),
        instanceId: 'b1',
      );
      state.board.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.destroy,
        count: 1,
        candidates: [c1],
        sourceZone: 'board',
      );

      ChoiceResolver.applySelection(state, [c1]);

      expect(state.triggerQueue.length, 1);
    });
  });

  group('ChoiceResolver.applySelection — pendingEffects', () {
    test('pendingEffects が空の場合は何も実行しない', () {
      final c1 = _makeCard('h1', CardType.spell);
      state.hand.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: 1,
        candidates: [c1],
        sourceZone: 'hand',
      );

      final result = ChoiceResolver.applySelection(state, [c1]);

      expect(result.success, isTrue);
      expect(result.awaitingChoice, isFalse);
    });

    test('sourceCard が add_counter の対象カードとして正しく渡される（source伝播バグの回帰テスト）', () {
      final source = _makeCard('src', CardType.artifact);
      final c1 = _makeCard('h1', CardType.spell);
      state.hand.add(c1);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: 1,
        candidates: [c1],
        sourceZone: 'hand',
        sourceCard: source,
        pendingEffects: const [
          EffectStep(op: 'add_counter', params: {'key': 'stack', 'amount': 3}),
        ],
      );

      final result = ChoiceResolver.applySelection(state, [c1]);

      expect(result.success, isTrue);
      expect(source.metadata['stack'], 3);
    });

    test('pendingEffects の途中でさらに選択が必要な場合 awaitingChoice を返し残りを保持する', () {
      final source = _makeCard('src', CardType.artifact);
      final c1 = _makeCard('h1', CardType.spell);
      final g1 = _makeCard('g1', CardType.spell);
      final g2 = _makeCard('g2', CardType.spell);
      state.hand.add(c1);
      state.grave.add(g1);
      state.grave.add(g2);
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: 1,
        candidates: [c1],
        sourceZone: 'hand',
        sourceCard: source,
        pendingEffects: const [
          EffectStep(
            op: 'move',
            params: {'from': 'grave', 'to': 'hand', 'count': 1, 'selection': 'choose'},
          ),
          EffectStep(op: 'add_counter', params: {'key': 'stack', 'amount': 1}),
        ],
      );

      final result = ChoiceResolver.applySelection(state, [c1]);

      expect(result.awaitingChoice, isTrue);
      expect(state.choiceRequest.value, isNotNull);
      expect(state.choiceRequest.value!.pendingEffects.length, 1);
      expect(state.choiceRequest.value!.pendingEffects.first.op, 'add_counter');
      // sourceCard は再度の選択待ちに引き継がれる
      expect(state.choiceRequest.value!.sourceCard, same(source));
    });
  });
}
