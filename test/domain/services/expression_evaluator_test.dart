import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/expression_evaluator.dart';

// テスト用カードインスタンスを生成するヘルパー
CardInstance _makeCard(
  String id,
  CardType type, {
  List<String> tags = const [],
}) {
  return CardInstance(
    card: CardData(id: id, name: id, type: type, tags: tags),
    instanceId: id,
  );
}

void main() {
  late GameState state;

  setUp(() {
    state = GameState();
  });

  group('ExpressionEvaluator - 基本参照子', () {
    test('hand.count >= 1 は hand に1枚あれば true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count >= 1"), isTrue);
    });

    test('hand.count >= 1 は hand が空なら false', () {
      expect(ExpressionEvaluator.evaluate(state, "hand.count >= 1"), isFalse);
    });

    test('deck.count == 0 は deck が空なら true', () {
      expect(ExpressionEvaluator.evaluate(state, "deck.count == 0"), isTrue);
    });

    test('deck.count == 0 は deck にカードがある場合 false', () {
      state.deck.add(_makeCard('a', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "deck.count == 0"), isFalse);
    });

    test('grave.count > 2 は grave が2枚以下なら false', () {
      state.grave.add(_makeCard('a', CardType.spell));
      state.grave.add(_makeCard('b', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "grave.count > 2"), isFalse);
    });

    test('grave.count > 2 は grave が3枚なら true', () {
      state.grave.add(_makeCard('a', CardType.spell));
      state.grave.add(_makeCard('b', CardType.spell));
      state.grave.add(_makeCard('c', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "grave.count > 2"), isTrue);
    });

    test('spells_cast_this_turn >= 3 は spellsCastThisTurn=3 で true', () {
      state.spellsCastThisTurn = 3;
      expect(ExpressionEvaluator.evaluate(state, "spells_cast_this_turn >= 3"), isTrue);
    });

    test('spells_cast_this_turn >= 3 は spellsCastThisTurn=2 で false', () {
      state.spellsCastThisTurn = 2;
      expect(ExpressionEvaluator.evaluate(state, "spells_cast_this_turn >= 3"), isFalse);
    });
  });

  group('ExpressionEvaluator - 比較演算子', () {
    test('>= 演算子: 左辺が右辺以上なら true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      state.hand.add(_makeCard('b', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count >= 2"), isTrue);
    });

    test('<= 演算子: 左辺が右辺以下なら true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count <= 1"), isTrue);
    });

    test('> 演算子: 左辺が右辺より大きい場合 true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      state.hand.add(_makeCard('b', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count > 1"), isTrue);
    });

    test('< 演算子: 左辺が右辺より小さい場合 true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count < 2"), isTrue);
    });

    test('== 演算子: 等しい場合 true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count == 1"), isTrue);
    });

    test('!= 演算子: 異なる場合 true', () {
      state.hand.add(_makeCard('a', CardType.spell));
      expect(ExpressionEvaluator.evaluate(state, "hand.count != 2"), isTrue);
    });
  });

  group('ExpressionEvaluator - count() 関数', () {
    test('count(type:artifact, zone:board:self) は board に artifact が2枚あれば true (>= 2)', () {
      state.board.add(_makeCard('a', CardType.artifact));
      state.board.add(_makeCard('b', CardType.artifact));
      expect(
        ExpressionEvaluator.evaluate(state, "count(type:'artifact', zone:'board:self') >= 2"),
        isTrue,
      );
    });

    test('count(type:artifact, zone:board:self) は artifact が1枚なら false (>= 2)', () {
      state.board.add(_makeCard('a', CardType.artifact));
      expect(
        ExpressionEvaluator.evaluate(state, "count(type:'artifact', zone:'board:self') >= 2"),
        isFalse,
      );
    });

    test('count(type:monster, zone:board:self) == 0 は board にモンスターがなければ true', () {
      state.board.add(_makeCard('a', CardType.artifact));
      expect(
        ExpressionEvaluator.evaluate(state, "count(type:'monster', zone:'board:self') == 0"),
        isTrue,
      );
    });

    test('count(tag:spl_haku, zone:hand:self) は hand に spl_haku タグが2枚で true (>= 2)', () {
      state.hand.add(_makeCard('h1', CardType.spell, tags: ['spl_haku']));
      state.hand.add(_makeCard('h2', CardType.spell, tags: ['spl_haku']));
      expect(
        ExpressionEvaluator.evaluate(state, "count(tag:'spl_haku', zone:'hand:self') >= 2"),
        isTrue,
      );
    });

    test('count(tag:spl_haku, zone:hand:self) はタグが1枚のとき false (>= 2)', () {
      state.hand.add(_makeCard('h1', CardType.spell, tags: ['spl_haku']));
      expect(
        ExpressionEvaluator.evaluate(state, "count(tag:'spl_haku', zone:'hand:self') >= 2"),
        isFalse,
      );
    });
  });

  group('ExpressionEvaluator - エラーケース', () {
    test('不正な式は例外を投げず false を返す', () {
      expect(ExpressionEvaluator.evaluate(state, "!!!invalid!!!"), isFalse);
    });

    test('空文字列は false を返す', () {
      expect(ExpressionEvaluator.evaluate(state, ""), isFalse);
    });
  });

  group('ExpressionEvaluator - self.counter() 参照', () {
    test("self.counter('spell_count') >= 4 はメタデータが4のとき true", () {
      final self = CardInstance(
        card: CardData(id: 'd1', name: 'd1', type: CardType.domain),
        instanceId: 'd1',
        metadata: {'spell_count': 4},
      );
      expect(
        ExpressionEvaluator.evaluate(state, "self.counter('spell_count') >= 4", self: self),
        isTrue,
      );
    });

    test("self.counter('spell_count') >= 4 はメタデータが3のとき false", () {
      final self = CardInstance(
        card: CardData(id: 'd1', name: 'd1', type: CardType.domain),
        instanceId: 'd1',
        metadata: {'spell_count': 3},
      );
      expect(
        ExpressionEvaluator.evaluate(state, "self.counter('spell_count') >= 4", self: self),
        isFalse,
      );
    });

    test("self.counter('spell_count') はメタデータ未設定のとき 0 を返す", () {
      final self = CardInstance(
        card: CardData(id: 'd1', name: 'd1', type: CardType.domain),
        instanceId: 'd1',
      );
      expect(
        ExpressionEvaluator.evaluate(state, "self.counter('spell_count') >= 1", self: self),
        isFalse,
      );
    });

    test("self が null のとき self.counter 式は false を返す", () {
      expect(
        ExpressionEvaluator.evaluate(state, "self.counter('spell_count') >= 1"),
        isFalse,
      );
    });
  });
}
