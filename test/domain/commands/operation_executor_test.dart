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

CardInstance _makeTaggedCard(String id, CardType type, List<String> tags) {
  return CardInstance(
    card: CardData(id: id, name: id, type: type, tags: tags),
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

  // ----------------------------------------------------------------
  group('op: discard (filter)', () {
    test('filter tag が1枚だけ一致 → 自動で grave に移動する', () {
      state.hand.add(_makeTaggedCard('h1', CardType.spell, ['burn']));
      state.hand.add(_makeTaggedCard('h2', CardType.spell, []));

      OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1, 'filter': {'tag': 'burn'}}));

      expect(state.grave.cards.first.card.id, 'h1');
    });

    test('filter tag が1枚だけ一致 → hand から消える', () {
      state.hand.add(_makeTaggedCard('h1', CardType.spell, ['burn']));
      state.hand.add(_makeTaggedCard('h2', CardType.spell, []));

      OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1, 'filter': {'tag': 'burn'}}));

      expect(state.hand.count, 1);
    });

    test('filter tag に一致するカードが不足する場合は failure を返す', () {
      state.hand.add(_makeTaggedCard('h1', CardType.spell, ['fire']));

      final result = OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1, 'filter': {'tag': 'burn'}}));

      expect(result.success, isFalse);
    });

    test('filter なしの discard は従来通り動作する', () {
      state.hand.add(_makeCard('h1', CardType.spell));
      state.hand.add(_makeCard('h2', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1}));

      expect(state.grave.count, 1);
    });

    test('filter 複数候補 → choiceRequest が設定される', () {
      state.hand.add(_makeTaggedCard('h1', CardType.spell, ['burn']));
      state.hand.add(_makeTaggedCard('h2', CardType.spell, ['burn']));

      OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1, 'filter': {'tag': 'burn'}}));

      expect(state.choiceRequest.value, isNotNull);
    });

    test('filter 複数候補 → awaitingChoice が true', () {
      state.hand.add(_makeTaggedCard('h1', CardType.spell, ['burn']));
      state.hand.add(_makeTaggedCard('h2', CardType.spell, ['burn']));

      final result = OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 1, 'filter': {'tag': 'burn'}}));

      expect(result.awaitingChoice, isTrue);
    });
  });

  // ----------------------------------------------------------------
  group('op: move (filter)', () {
    test('filter tag が1枚一致 → 自動移動する', () {
      state.grave.add(_makeTaggedCard('g1', CardType.spell, ['token']));
      state.grave.add(_makeTaggedCard('g2', CardType.spell, []));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1, 'filter': {'tag': 'token'}}));

      expect(state.hand.cards.first.card.id, 'g1');
    });

    test('filter tag が1枚一致 → 元ゾーンから消える', () {
      state.grave.add(_makeTaggedCard('g1', CardType.spell, ['token']));
      state.grave.add(_makeTaggedCard('g2', CardType.spell, []));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1, 'filter': {'tag': 'token'}}));

      expect(state.grave.count, 1);
    });

    test('filter tag に一致しないカードは移動されない', () {
      state.grave.add(_makeTaggedCard('g1', CardType.spell, ['fire']));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1, 'filter': {'tag': 'token'}}));

      expect(state.hand.count, 0);
    });

    test('filter 複数候補 → choiceRequest が設定される', () {
      state.grave.add(_makeTaggedCard('g1', CardType.spell, ['token']));
      state.grave.add(_makeTaggedCard('g2', CardType.spell, ['token']));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1, 'filter': {'tag': 'token'}}));

      expect(state.choiceRequest.value, isNotNull);
    });
  });

  // ----------------------------------------------------------------
  group('op: destroy (filter)', () {
    test('filter tag が1枚一致 → 自動破壊される', () {
      state.board.add(_makeTaggedCard('b1', CardType.monster, ['weak']));
      state.board.add(_makeTaggedCard('b2', CardType.monster, []));

      OperationExecutor.executeOperation(
          state, _op('destroy', {'target': 'board', 'filter': {'tag': 'weak'}}));

      expect(state.grave.cards.first.card.id, 'b1');
    });

    test('filter tag が1枚一致 → board から消える', () {
      state.board.add(_makeTaggedCard('b1', CardType.monster, ['weak']));
      state.board.add(_makeTaggedCard('b2', CardType.monster, []));

      OperationExecutor.executeOperation(
          state, _op('destroy', {'target': 'board', 'filter': {'tag': 'weak'}}));

      expect(state.board.count, 1);
    });

    test('filter tag に一致するカードがない場合は failure を返す', () {
      state.board.add(_makeTaggedCard('b1', CardType.monster, ['strong']));

      final result = OperationExecutor.executeOperation(
          state, _op('destroy', {'target': 'board', 'filter': {'tag': 'weak'}}));

      expect(result.success, isFalse);
    });

    test('filter 複数候補 → choiceRequest が設定される', () {
      state.board.add(_makeTaggedCard('b1', CardType.monster, ['weak']));
      state.board.add(_makeTaggedCard('b2', CardType.monster, ['weak']));

      OperationExecutor.executeOperation(
          state, _op('destroy', {'target': 'board', 'count': 1, 'filter': {'tag': 'weak'}}));

      expect(state.choiceRequest.value, isNotNull);
    });

    test('count=2 で filter 一致の2枚が破壊される', () {
      state.board.add(_makeTaggedCard('b1', CardType.monster, ['weak']));
      state.board.add(_makeTaggedCard('b2', CardType.monster, ['weak']));

      OperationExecutor.executeOperation(
          state, _op('destroy', {'target': 'board', 'count': 2, 'filter': {'tag': 'weak'}}));

      expect(state.grave.count, 2);
    });
  });

  // ----------------------------------------------------------------
  group('op: search', () {
    test('random: true でデッキの artifact カードが手札に移動する', () {
      state.deck.add(_makeCard('a1', CardType.artifact));
      state.deck.add(_makeCard('s1', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('search', {'from': 'deck', 'to': 'hand', 'filter': {'type': 'artifact'}, 'max': 1, 'random': true}));

      expect(state.hand.count, 1);
    });

    test('random: true でデッキの artifact カードが手札に移動し、デッキから消える', () {
      state.deck.add(_makeCard('a1', CardType.artifact));
      state.deck.add(_makeCard('s1', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('search', {'from': 'deck', 'to': 'hand', 'filter': {'type': 'artifact'}, 'max': 1, 'random': true}));

      expect(state.deck.cards.any((c) => c.card.id == 'a1'), isFalse);
    });

    test('random: true でデッキに artifact がない場合は手札に変化なし', () {
      state.deck.add(_makeCard('s1', CardType.spell));
      state.deck.add(_makeCard('s2', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('search', {'from': 'deck', 'to': 'hand', 'filter': {'type': 'artifact'}, 'max': 1, 'random': true}));

      expect(state.hand.count, 0);
    });

    test('random: true で複数の artifact がある場合も1枚だけ手札に加わる', () {
      state.deck.add(_makeCard('a1', CardType.artifact));
      state.deck.add(_makeCard('a2', CardType.artifact));
      state.deck.add(_makeCard('a3', CardType.artifact));

      OperationExecutor.executeOperation(
          state, _op('search', {'from': 'deck', 'to': 'hand', 'filter': {'type': 'artifact'}, 'max': 1, 'random': true}));

      expect(state.hand.count, 1);
    });
  });

  // ----------------------------------------------------------------
  group('op: discard (selection: choose)', () {
    test('selection=choose かつ候補が count より多い → choiceRequest が設定される', () {
      state.hand.add(_makeCard('h1', CardType.spell));
      state.hand.add(_makeCard('h2', CardType.spell));
      state.hand.add(_makeCard('h3', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 2, 'selection': 'choose'}));

      expect(state.choiceRequest.value, isNotNull);
    });

    test('selection=choose かつ候補が count より多い → awaitingChoice が true', () {
      state.hand.add(_makeCard('h1', CardType.spell));
      state.hand.add(_makeCard('h2', CardType.spell));
      state.hand.add(_makeCard('h3', CardType.spell));

      final result = OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 2, 'selection': 'choose'}));

      expect(result.awaitingChoice, isTrue);
    });

    test('selection=choose かつ候補が count と同数 → 自動で grave に移動する', () {
      state.hand.add(_makeCard('h1', CardType.spell));
      state.hand.add(_makeCard('h2', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('discard', {'from': 'hand', 'count': 2, 'selection': 'choose'}));

      expect(state.grave.count, 2);
    });
  });

  // ----------------------------------------------------------------
  group('op: move (selection: choose)', () {
    test('selection=choose かつ候補が count より多い → choiceRequest が設定される', () {
      state.grave.add(_makeCard('g1', CardType.spell));
      state.grave.add(_makeCard('g2', CardType.spell));
      state.grave.add(_makeCard('g3', CardType.spell));

      OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1, 'selection': 'choose'}));

      expect(state.choiceRequest.value, isNotNull);
    });

    test('selection=choose かつ候補が count より多い → awaitingChoice が true', () {
      state.grave.add(_makeCard('g1', CardType.spell));
      state.grave.add(_makeCard('g2', CardType.spell));

      final result = OperationExecutor.executeOperation(
          state, _op('move', {'from': 'grave', 'to': 'hand', 'count': 1, 'selection': 'choose'}));

      expect(result.awaitingChoice, isTrue);
    });
  });
}
