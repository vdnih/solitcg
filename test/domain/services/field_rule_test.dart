import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/field_rule.dart';

CardInstance _makeCard(String id, CardType type, {List<Ability> abilities = const []}) {
  return CardInstance(
    card: CardData(id: id, name: id, type: type, abilities: abilities),
    instanceId: id,
  );
}

Ability _makeAbility(TriggerWhen when, {List<EffectStep> effects = const []}) {
  return Ability(when: when, effects: effects);
}

void main() {
  late GameState state;

  setUp(() {
    state = GameState();
  });

  // ----------------------------------------------------------------
  group('FieldRule.playCard — spell', () {
    test('spell をプレイすると grave に移動する', () {
      final card = _makeCard('s1', CardType.spell);

      FieldRule.playCard(state, card);

      expect(state.grave.count, 1);
    });

    test('spell をプレイすると board には残らない', () {
      final card = _makeCard('s1', CardType.spell);

      FieldRule.playCard(state, card);

      expect(state.board.count, 0);
    });

    test('spell をプレイすると spellsCastThisTurn が +1 される', () {
      final card = _makeCard('s1', CardType.spell);

      FieldRule.playCard(state, card);

      expect(state.spellsCastThisTurn, 1);
    });

    test('spell の on_play アビリティがトリガーキューに積まれる', () {
      final ability = _makeAbility(TriggerWhen.onPlay);
      final card = _makeCard('s1', CardType.spell, abilities: [ability]);

      FieldRule.playCard(state, card);

      expect(state.triggerQueue.length, 1);
    });
  });

  // ----------------------------------------------------------------
  group('FieldRule.playCard — arcane', () {
    test('arcane をプレイすると grave に移動する', () {
      final card = _makeCard('a1', CardType.arcane);

      FieldRule.playCard(state, card);

      expect(state.grave.count, 1);
    });

    test('arcane をプレイすると spellsCastThisTurn が +1 される', () {
      final card = _makeCard('a1', CardType.arcane);

      FieldRule.playCard(state, card);

      expect(state.spellsCastThisTurn, 1);
    });
  });

  // ----------------------------------------------------------------
  group('FieldRule.playCard — monster', () {
    test('monster をプレイすると board に追加される', () {
      final card = _makeCard('m1', CardType.monster);

      FieldRule.playCard(state, card);

      expect(state.board.count, 1);
    });

    test('monster をプレイすると grave には移動しない', () {
      final card = _makeCard('m1', CardType.monster);

      FieldRule.playCard(state, card);

      expect(state.grave.count, 0);
    });

    test('monster の on_play アビリティがトリガーキューに積まれる', () {
      final ability = _makeAbility(TriggerWhen.onPlay);
      final card = _makeCard('m1', CardType.monster, abilities: [ability]);

      FieldRule.playCard(state, card);

      expect(state.triggerQueue.length, 1);
    });
  });

  // ----------------------------------------------------------------
  group('FieldRule.playCard — artifact', () {
    test('artifact をプレイすると board に追加される', () {
      final card = _makeCard('ar1', CardType.artifact);

      FieldRule.playCard(state, card);

      expect(state.board.count, 1);
    });
  });

  // ----------------------------------------------------------------
  group('FieldRule.playDomain — ドメイン置換裁定', () {
    test('既存ドメインなしで playDomain すると domain ゾーンに1枚入る', () {
      final card = _makeCard('d1', CardType.domain);

      FieldRule.playDomain(state, card);

      expect(state.domain.count, 1);
    });

    test('既存ドメインありで新しいドメインをプレイすると旧ドメインが grave に移動する', () {
      final oldDomain = _makeCard('d_old', CardType.domain);
      final newDomain = _makeCard('d_new', CardType.domain);
      state.domain.add(oldDomain);

      FieldRule.playDomain(state, newDomain);

      expect(state.grave.count, 1);
      expect(state.grave.cards.first.instanceId, 'd_old');
    });

    test('既存ドメインの on_destroy アビリティがキューに積まれる', () {
      final onDestroyAbility = _makeAbility(TriggerWhen.onDestroy);
      final oldDomain = _makeCard('d_old', CardType.domain, abilities: [onDestroyAbility]);
      final newDomain = _makeCard('d_new', CardType.domain);
      state.domain.add(oldDomain);

      FieldRule.playDomain(state, newDomain);

      expect(state.triggerQueue.length, 1);
    });

    test('非 domain カードを playDomain に渡すと failure を返す', () {
      final spell = _makeCard('s1', CardType.spell);

      final result = FieldRule.playDomain(state, spell);

      expect(result.success, isFalse);
    });
  });

  // ----------------------------------------------------------------
  group('FieldRule.playCard — on_spell_played domain 通知', () {
    test('spell をプレイすると domain の onSpellPlayed アビリティがキューに積まれる', () {
      final onSpellPlayedAbility = _makeAbility(TriggerWhen.onSpellPlayed);
      final domain = _makeCard('d1', CardType.domain, abilities: [onSpellPlayedAbility]);
      state.domain.add(domain);

      final spell = _makeCard('s1', CardType.spell);
      FieldRule.playCard(state, spell);

      expect(state.triggerQueue.length, 1);
      expect(state.triggerQueue.first.ability.when, TriggerWhen.onSpellPlayed);
    });

    test('domain がないとき spell をプレイしても onSpellPlayed はキューに積まれない', () {
      final spell = _makeCard('s1', CardType.spell);
      FieldRule.playCard(state, spell);

      expect(state.triggerQueue.length, 0);
    });

    test('arcane をプレイしても domain の onSpellPlayed が通知される', () {
      final onSpellPlayedAbility = _makeAbility(TriggerWhen.onSpellPlayed);
      final domain = _makeCard('d1', CardType.domain, abilities: [onSpellPlayedAbility]);
      state.domain.add(domain);

      final arcane = _makeCard('a1', CardType.arcane);
      FieldRule.playCard(state, arcane);

      expect(state.triggerQueue.length, 1);
      expect(state.triggerQueue.first.ability.when, TriggerWhen.onSpellPlayed);
    });

    test('spell の on_play と domain の onSpellPlayed が両方キューに積まれる', () {
      final onPlayAbility = _makeAbility(TriggerWhen.onPlay);
      final spell = _makeCard('s1', CardType.spell, abilities: [onPlayAbility]);

      final onSpellPlayedAbility = _makeAbility(TriggerWhen.onSpellPlayed);
      final domain = _makeCard('d1', CardType.domain, abilities: [onSpellPlayedAbility]);
      state.domain.add(domain);

      FieldRule.playCard(state, spell);

      expect(state.triggerQueue.length, 2);
    });
  });

  // ----------------------------------------------------------------
  group('FieldRule.playCardFromHand — エラーケース', () {
    test('無効なインデックス（負数）は failure を返す', () {
      final result = FieldRule.playCardFromHand(state, -1);

      expect(result.success, isFalse);
    });

    test('無効なインデックス（範囲外）は failure を返す', () {
      state.hand.add(_makeCard('c1', CardType.spell));

      final result = FieldRule.playCardFromHand(state, 1);

      expect(result.success, isFalse);
    });

    test('pre 条件を満たさないカードは failure を返す', () {
      // hand.count >= 5 という満たせない条件を持つカード
      final ability = Ability(
        when: TriggerWhen.onPlay,
        pre: ["hand.count >= 5"],
        effects: const [],
      );
      state.hand.add(_makeCard('s1', CardType.spell, abilities: [ability]));

      final result = FieldRule.playCardFromHand(state, 0);

      expect(result.success, isFalse);
    });

    test('条件を満たすカードは成功し、hand から消える', () {
      state.hand.add(_makeCard('s1', CardType.spell));

      final result = FieldRule.playCardFromHand(state, 0);

      expect(result.success, isTrue);
      expect(state.hand.count, 0);
    });
  });
}
