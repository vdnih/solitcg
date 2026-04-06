import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/commands/operation_executor.dart';

CardInstance _makeCard(String id, CardType type, {List<Ability> abilities = const []}) {
  return CardInstance(
    card: CardData(id: id, name: id, type: type, abilities: abilities),
    instanceId: id,
  );
}

EffectStep _op(String op, [Map<String, dynamic> params = const {}]) {
  return EffectStep(op: op, params: params);
}

void main() {
  late GameState state;

  setUp(() {
    state = GameState();
  });

  // ----------------------------------------------------------------
  group('op: draw', () {
    test('count=2 で hand に2枚追加される', () {
      state.deck.add(_makeCard('d1', CardType.spell));
      state.deck.add(_makeCard('d2', CardType.spell));

      OperationExecutor.executeOperation(state, _op('draw', {'count': 2}));

      expect(state.hand.count, 2);
    });

    test('count=2 で deck が2枚減る', () {
      state.deck.add(_makeCard('d1', CardType.spell));
      state.deck.add(_makeCard('d2', CardType.spell));

      OperationExecutor.executeOperation(state, _op('draw', {'count': 2}));

      expect(state.deck.count, 0);
    });
  });

  // ----------------------------------------------------------------
  group('op: discard', () {
    test('count=1 で hand から grave に1枚移動する', () {
      state.hand.add(_makeCard('h1', CardType.spell));

      OperationExecutor.executeOperation(state, _op('discard', {'from': 'hand', 'count': 1}));

      expect(state.grave.count, 1);
    });

    test('count=1 で hand が1枚減る', () {
      state.hand.add(_makeCard('h1', CardType.spell));
      state.hand.add(_makeCard('h2', CardType.spell));

      OperationExecutor.executeOperation(state, _op('discard', {'from': 'hand', 'count': 1}));

      expect(state.hand.count, 1);
    });

    test('捨てられたカードの on_discard アビリティがキューに積まれる', () {
      final ability = Ability(when: TriggerWhen.onDiscard, effects: const []);
      state.hand.add(_makeCard('h1', CardType.spell, abilities: [ability]));

      OperationExecutor.executeOperation(state, _op('discard', {'from': 'hand', 'count': 1}));

      expect(state.triggerQueue.length, 1);
    });

    test('手札が足りない場合は failure を返す', () {
      // hand が空

      final result = OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1}));

      expect(result.success, isFalse);
    });
  });

  // ----------------------------------------------------------------
  group('op: win', () {
    test('実行後 gameWon が true になる', () {
      OperationExecutor.executeOperation(state, _op('win'));

      expect(state.gameWon, isTrue);
    });

    test('success を返す', () {
      final result = OperationExecutor.executeOperation(state, _op('win'));

      expect(result.success, isTrue);
    });
  });

  // ----------------------------------------------------------------
  group('op: win_if', () {
    test('条件成立時 gameWon が true になる', () {
      state.spellsCastThisTurn = 7;

      OperationExecutor.executeOperation(
          state, _op('win_if', {'expr': 'spells_cast_this_turn >= 7'}));

      expect(state.gameWon, isTrue);
    });

    test('条件不成立時 gameWon が false のまま', () {
      state.spellsCastThisTurn = 3;

      OperationExecutor.executeOperation(
          state, _op('win_if', {'expr': 'spells_cast_this_turn >= 7'}));

      expect(state.gameWon, isFalse);
    });
  });

  // ----------------------------------------------------------------
  group('op: lose_if', () {
    test('条件成立時 gameLost が true になる', () {
      // hand も deck も空

      OperationExecutor.executeOperation(
          state, _op('lose_if', {'expr': 'hand.count == 0'}));

      expect(state.gameLost, isTrue);
    });

    test('条件不成立時 gameLost が false のまま', () {
      state.hand.add(_makeCard('h1', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('lose_if', {'expr': 'hand.count == 0'}));

      expect(state.gameLost, isFalse);
    });
  });

  // ----------------------------------------------------------------
  group('op: destroy', () {
    test('board のカードが grave に移動する', () {
      state.board.add(_makeCard('b1', CardType.monster));

      OperationExecutor.executeOperation(state, _op('destroy', {'target': 'board'}));

      expect(state.grave.count, 1);
    });

    test('board のカードが board から消える', () {
      state.board.add(_makeCard('b1', CardType.monster));

      OperationExecutor.executeOperation(state, _op('destroy', {'target': 'board'}));

      expect(state.board.count, 0);
    });

    test('破壊されたカードの on_destroy アビリティがキューに積まれる', () {
      final ability = Ability(when: TriggerWhen.onDestroy, effects: const []);
      state.board.add(_makeCard('b1', CardType.monster, abilities: [ability]));

      OperationExecutor.executeOperation(state, _op('destroy', {'target': 'board'}));

      expect(state.triggerQueue.length, 1);
    });

    test('対象がない場合は failure を返す', () {
      // board が空

      final result = OperationExecutor.executeOperation(
          state, _op('destroy', {'target': 'board'}));

      expect(result.success, isFalse);
    });
  });

  // ----------------------------------------------------------------
  group('op: move', () {
    test('grave から hand に1枚移動する', () {
      state.grave.add(_makeCard('g1', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1}));

      expect(state.hand.count, 1);
    });

    test('move 後 grave が1枚減る', () {
      state.grave.add(_makeCard('g1', CardType.spell));
      state.grave.add(_makeCard('g2', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1}));

      expect(state.grave.count, 1);
    });
  });

  // ----------------------------------------------------------------
  group('op: mill', () {
    test('count=2 で deck から grave に2枚移動する', () {
      state.deck.add(_makeCard('d1', CardType.spell));
      state.deck.add(_makeCard('d2', CardType.spell));
      state.deck.add(_makeCard('d3', CardType.spell));

      OperationExecutor.executeOperation(state, _op('mill', {'count': 2}));

      expect(state.grave.count, 2);
    });

    test('count=2 で deck が2枚減る', () {
      state.deck.add(_makeCard('d1', CardType.spell));
      state.deck.add(_makeCard('d2', CardType.spell));
      state.deck.add(_makeCard('d3', CardType.spell));

      OperationExecutor.executeOperation(state, _op('mill', {'count': 2}));

      expect(state.deck.count, 1);
    });
  });

  // ----------------------------------------------------------------
  group('未知の op', () {
    test('未定義の op は failure を返す', () {
      final result = OperationExecutor.executeOperation(
          state, _op('unknown_op'));

      expect(result.success, isFalse);
    });
  });
}
