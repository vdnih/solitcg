import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/commands/operation_executor.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/field_rule.dart';

/// 40枚の区別可能なカードでデッキを組んだ GameState を返す。
GameState _stateWithDeck(int seed) {
  final state = GameState(seed: seed);
  for (int i = 0; i < 40; i++) {
    final type = i.isEven ? CardType.spell : CardType.monster;
    state.deck.add(CardInstance(
      card: CardData(id: 'c$i', name: 'c$i', type: type),
      instanceId: 'c$i',
    ));
  }
  return state;
}

List<String> _ids(List<CardInstance> cards) =>
    cards.map((c) => c.instanceId).toList();

/// 初期手札を配り、random サーチ（デッキ再シャッフルを伴う）を1回行ったあとの
/// 手札とデッキの並びを返す。
List<String> _playSomeRandomSteps(int seed) {
  final state = _stateWithDeck(seed);
  FieldRule.dealInitialHand(state);
  OperationExecutor.executeOperation(
    state,
    EffectStep(op: 'search', params: {
      'from': 'deck',
      'to': 'hand',
      'filter': {'type': 'monster'},
      'max': 2,
      'random': true,
    }),
  );
  return [
    ..._ids(state.hand.cards),
    '|',
    ..._ids(state.deck.cards),
  ];
}

void main() {
  group('GameState の seed', () {
    test('seed を指定するとその値を保持する', () {
      expect(GameState(seed: 42).seed, 42);
    });

    test('seed を省略しても seed が採番され、random が使える', () {
      final state = GameState();

      expect(state.seed, isNonNegative);
      expect(state.random.nextInt(10), inInclusiveRange(0, 9));
    });
  });

  group('FieldRule.dealInitialHand', () {
    test('初期手札を5枚配る', () {
      final state = _stateWithDeck(1);

      FieldRule.dealInitialHand(state);

      expect(state.hand.count, FieldRule.initialHandSize);
      expect(state.deck.count, 40 - FieldRule.initialHandSize);
    });

    test('同じ seed なら初期手札とデッキの並びが一致する', () {
      final a = _stateWithDeck(123);
      final b = _stateWithDeck(123);

      FieldRule.dealInitialHand(a);
      FieldRule.dealInitialHand(b);

      expect(_ids(a.hand.cards), _ids(b.hand.cards));
      expect(_ids(a.deck.cards), _ids(b.deck.cards));
    });

    test('異なる seed ならデッキの並びが変わる', () {
      final a = _stateWithDeck(1);
      final b = _stateWithDeck(2);

      FieldRule.dealInitialHand(a);
      FieldRule.dealInitialHand(b);

      expect(_ids(a.deck.cards), isNot(_ids(b.deck.cards)));
    });
  });

  group('ゲーム中の乱数', () {
    test('同じ seed なら random サーチとデッキ再シャッフルの結果まで一致する', () {
      expect(_playSomeRandomSteps(777), _playSomeRandomSteps(777));
    });

    test('異なる seed なら結果が変わる', () {
      expect(_playSomeRandomSteps(1), isNot(_playSomeRandomSteps(2)));
    });
  });
}
