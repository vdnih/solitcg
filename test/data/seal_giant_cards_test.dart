import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/data/repositories/card_repository.dart';
import 'package:solitcg/domain/models/card_instance.dart';
import 'package:solitcg/domain/services/choice_resolver.dart';
import 'package:solitcg/domain/services/field_rule.dart';
import 'package:solitcg/domain/services/trigger_service.dart';

/// 封印されし巨神と3テーマ（魔導書庫・星詠み・銀眼）のカードが、
/// assets/cards の実 YAML どおりに動くことを検証する統合テスト。

int _seq = 0;

CardInstance _card(String id) {
  final card = CardRepository.parseCard(
      File('assets/cards/$id.yaml').readAsStringSync());
  if (card == null) throw StateError('failed to parse $id.yaml');
  return CardInstance(card: card, instanceId: '${id}_${_seq++}');
}

List<CardInstance> _cards(List<String> ids) => ids.map(_card).toList();

List<String> _ids(Iterable<CardInstance> cards) =>
    cards.map((c) => c.card.id).toList();

Future<void> _resolve(GameState state) =>
    TriggerService.resolveAll(state, () {}, stepDelay: Duration.zero);

/// 手札の [id] をプレイしてトリガーを解決する。プレイ自体の成否を返す。
Future<bool> _play(GameState state, String id) async {
  final index = state.hand.cards.indexWhere((c) => c.card.id == id);
  expect(index, isNot(-1), reason: '$id is not in hand');
  final result = FieldRule.playCardFromHand(state, index);
  if (result.success) await _resolve(state);
  return result.success;
}

/// 選択待ちの候補から [ids] のカードを選んで確定し、トリガー解決を再開する。
Future<void> _choose(GameState state, List<String> ids) async {
  final request = state.choiceRequest.value;
  expect(request, isNotNull, reason: 'no pending choice');
  final remaining = [...request!.candidates];
  final selected = <CardInstance>[];
  for (final id in ids) {
    final card = remaining.firstWhere((c) => c.card.id == id);
    remaining.remove(card);
    selected.add(card);
  }
  final result = ChoiceResolver.applySelection(state, selected);
  if (!result.awaitingChoice && state.choiceRequest.value == null) {
    await _resolve(state);
  }
}

void main() {
  late GameState state;

  setUp(() {
    state = GameState(seed: 1);
  });

  group('封印されし巨神', () {
    const limbs = [
      'seal_giant_right_arm',
      'seal_giant_left_arm',
      'seal_giant_right_leg',
      'seal_giant_left_leg',
    ];

    test('四肢が手札に揃っていれば、頭部を召喚して勝利する', () async {
      state.hand.addAll(_cards(['seal_giant_head', ...limbs]));

      expect(await _play(state, 'seal_giant_head'), isTrue);
      expect(state.gameWon, isTrue);
    });

    test('四肢が1種でも欠けていれば頭部は召喚できない（同じ部位の重複では代替できない）', () async {
      state.hand.addAll(_cards([
        'seal_giant_head',
        'seal_giant_right_arm',
        'seal_giant_left_arm',
        'seal_giant_right_leg',
        'seal_giant_right_leg',
      ]));

      expect(await _play(state, 'seal_giant_head'), isFalse);
      expect(state.gameWon, isFalse);
      expect(state.hand.count, 5);
    });

    test('封印の宝櫃: 手札を1枚捨て、デッキから巨神のパーツを選んで手札に加える', () async {
      state.hand
          .addAll(_cards(['sealed_coffer', 'simple_draw_001', 'spl_typhoon']));
      state.deck.addAll(_cards(
          ['simple_draw_001', 'seal_giant_left_leg', 'seal_giant_head']));

      await _play(state, 'sealed_coffer');
      await _choose(state, ['spl_typhoon']);
      await _choose(state, ['seal_giant_left_leg']);

      expect(
          _ids(state.hand.cards), ['simple_draw_001', 'seal_giant_left_leg']);
      expect(_ids(state.deck.cards), ['simple_draw_001', 'seal_giant_head']);
    });

    test('封印の宝櫃: 捨てる手札が無ければサーチも行われない', () async {
      state.hand.addAll(_cards(['sealed_coffer']));
      state.deck.addAll(_cards(['seal_giant_head']));

      await _play(state, 'sealed_coffer');

      expect(state.hand.count, 0);
      expect(state.deck.count, 1);
    });

    test('量産工房: 墓地の vanilla モンスター2体を手札に戻す', () async {
      state.grave.addAll(_cards(
          ['seal_giant_right_arm', 'mon_akuma_001', 'silver_eyes_dragon']));
      state.hand.addAll(_cards(['mass_production_workshop']));

      await _play(state, 'mass_production_workshop');

      expect(_ids(state.hand.cards),
          ['seal_giant_right_arm', 'silver_eyes_dragon']);
    });

    test('量産工房: 墓地の vanilla モンスターが1体以下なら発動できない', () async {
      state.grave.addAll(_cards(['seal_giant_right_arm', 'mon_akuma_001']));
      state.hand.addAll(_cards(['mass_production_workshop']));

      expect(await _play(state, 'mass_production_workshop'), isFalse);
    });
  });

  group('王立魔導書庫', () {
    test('スペル3回ごとにカウンターを取り除いて1枚引く', () async {
      final library = _card('royal_grimoire_library');
      state.board.add(library);
      state.hand.addAll(_cards(['sorting_pot', 'sorting_pot', 'sorting_pot']));
      state.deck.addAll(_cards(List.filled(10, 'mon_van_001')));

      await _play(state, 'sorting_pot');
      await _play(state, 'sorting_pot');
      expect(library.metadata['magic'], 2);

      await _play(state, 'sorting_pot');
      // 選別の壺3回で3枚 + 書庫で1枚
      expect(state.hand.count, 4);
      expect(library.metadata['magic'], 0);
    });

    test('場に2体並べると、それぞれがカウンターを貯めてドローする', () async {
      state.board
          .addAll(_cards(['royal_grimoire_library', 'royal_grimoire_library']));
      state.hand.addAll(_cards(['sorting_pot', 'sorting_pot', 'sorting_pot']));
      state.deck.addAll(_cards(List.filled(15, 'mon_van_001')));

      for (int i = 0; i < 3; i++) {
        await _play(state, 'sorting_pot');
      }

      expect(state.hand.count, 5);
    });

    test('魔導書の司書: 召喚したとき、デッキから grimoire を選んで手札に加える', () async {
      state.hand.addAll(_cards(['grimoire_scholar']));
      state.deck.addAll(
          _cards(['grimoire_of_secrets', 'mon_van_001', 'grimoire_of_wisdom']));

      await _play(state, 'grimoire_scholar');
      await _choose(state, ['grimoire_of_wisdom']);

      expect(_ids(state.hand.cards), ['grimoire_of_wisdom']);
    });

    test('秘伝の魔導書: 同名カードを連鎖してサーチできる', () async {
      state.hand.addAll(_cards(['grimoire_of_secrets']));
      state.deck.addAll(_cards(['mon_van_001', 'grimoire_of_secrets']));

      await _play(state, 'grimoire_of_secrets');

      expect(_ids(state.hand.cards), ['grimoire_of_secrets']);
      expect(_ids(state.deck.cards), ['mon_van_001']);
    });

    test('叡智の魔導書: 手札の grimoire を1枚捨てて2枚引く', () async {
      state.hand.addAll(
          _cards(['grimoire_of_wisdom', 'grimoire_of_secrets', 'mon_van_001']));
      state.deck.addAll(_cards(['mon_warrior_001', 'mon_warrior_001']));

      await _play(state, 'grimoire_of_wisdom');

      expect(_ids(state.hand.cards),
          ['mon_van_001', 'mon_warrior_001', 'mon_warrior_001']);
      expect(_ids(state.grave.cards), contains('grimoire_of_secrets'));
    });

    test('叡智の魔導書: 手札に grimoire が無ければ引けない', () async {
      state.hand.addAll(_cards(['grimoire_of_wisdom', 'mon_van_001']));
      state.deck.addAll(_cards(['mon_warrior_001', 'mon_warrior_001']));

      await _play(state, 'grimoire_of_wisdom');

      expect(_ids(state.hand.cards), ['mon_van_001']);
      expect(state.deck.count, 2);
    });

    test('選別の壺: デッキの上から2枚を墓地へ送り、1枚引く', () async {
      state.hand.addAll(_cards(['sorting_pot']));
      state.deck.addAll(_cards(
          ['seal_giant_right_arm', 'seal_giant_left_arm', 'mon_van_001']));

      await _play(state, 'sorting_pot');

      expect(_ids(state.hand.cards), ['mon_van_001']);
      expect(_ids(state.grave.cards),
          containsAll(['seal_giant_right_arm', 'seal_giant_left_arm']));
    });
  });

  group('星詠み', () {
    test('アクア: 自分以外の星詠みが場にいれば召喚時に2枚引く', () async {
      state.board.addAll(_cards(['stargazer_lumina']));
      state.hand.addAll(_cards(['stargazer_aqua']));
      state.deck.addAll(_cards(['mon_van_001', 'mon_van_001']));

      await _play(state, 'stargazer_aqua');

      expect(state.hand.count, 2);
    });

    test('アクア: 場に他の星詠みがいなくても召喚はできるが、引けない', () async {
      state.hand.addAll(_cards(['stargazer_aqua']));
      state.deck.addAll(_cards(['mon_van_001', 'mon_van_001']));

      expect(await _play(state, 'stargazer_aqua'), isTrue);

      expect(_ids(state.board.cards), ['stargazer_aqua']);
      expect(state.hand.count, 0);
    });

    test('運命の転輪でルミナを破壊すると、1枚引きデッキの星詠みが場に出る（召喚時効果は発動しない）', () async {
      state.board.addAll(_cards(['stargazer_lumina']));
      state.hand.addAll(_cards(['wheel_of_fortune']));
      state.deck
          .addAll(_cards(['mon_van_001', 'mon_van_001', 'stargazer_aqua']));

      await _play(state, 'wheel_of_fortune');

      expect(_ids(state.board.cards), ['stargazer_aqua']);
      // 転輪の1枚のみ。デッキから出たアクアのドローは発動しない
      expect(_ids(state.hand.cards), ['mon_van_001']);
    });

    test('運命の転輪: 場に星詠みがいなければ引けない', () async {
      state.board.addAll(_cards(['royal_grimoire_library']));
      state.hand.addAll(_cards(['wheel_of_fortune']));
      state.deck.addAll(_cards(['mon_van_001']));

      await _play(state, 'wheel_of_fortune');

      expect(state.hand.count, 0);
      expect(state.board.count, 1);
    });

    test('クロノ: 手札から捨てられると、墓地の星詠み（自身を含む）を場に出す', () async {
      state.hand
          .addAll(_cards(['spl_typhoon', 'stargazer_chrono', 'mon_van_001']));
      state.deck.addAll(_cards(['mon_warrior_001', 'mon_warrior_001']));

      await _play(state, 'spl_typhoon');
      await _choose(state, ['stargazer_chrono', 'mon_van_001']);

      expect(_ids(state.board.cards), ['stargazer_chrono']);
    });

    test('星の未来図: 墓地の星詠みをデッキの一番下に戻して2枚引く', () async {
      state.grave.addAll(_cards(['stargazer_lumina']));
      state.hand.addAll(_cards(['stargazer_future_chart']));
      state.deck.addAll(_cards(['mon_van_001', 'mon_van_001']));

      await _play(state, 'stargazer_future_chart');

      expect(state.hand.count, 2);
      expect(_ids(state.deck.cards), ['stargazer_lumina']);
    });

    test('星の未来図: 墓地に星詠みがいなければ発動できない', () async {
      state.hand.addAll(_cards(['stargazer_future_chart']));
      state.deck.addAll(_cards(['mon_van_001', 'mon_van_001']));

      expect(await _play(state, 'stargazer_future_chart'), isFalse);
    });
  });

  group('銀眼の白竜', () {
    test('上級交換: 手札の high_level を1体捨てて2枚引く', () async {
      state.hand.addAll(_cards(['high_level_trade', 'silver_eyes_dragon']));
      state.deck.addAll(_cards(['mon_van_001', 'mon_van_001']));

      await _play(state, 'high_level_trade');

      expect(_ids(state.hand.cards), ['mon_van_001', 'mon_van_001']);
    });

    test('上級交換: 手札に high_level が無ければ引けない', () async {
      state.hand.addAll(_cards(['high_level_trade', 'white_legend_stone']));
      state.deck.addAll(_cards(['mon_van_001', 'mon_van_001']));

      await _play(state, 'high_level_trade');

      expect(_ids(state.hand.cards), ['white_legend_stone']);
    });

    test('竜呼びの旋律で白き伝承の石を捨てると、旋律で2体・石で1体の上級竜が手札に入る', () async {
      state.hand.addAll(_cards(
          ['dragon_calling_melody', 'white_legend_stone', 'mon_van_001']));
      state.deck.addAll(_cards([
        'silver_eyes_dragon',
        'silver_eyes_dragon',
        'silver_eyes_dragon',
        'mon_warrior_001'
      ]));

      await _play(state, 'dragon_calling_melody');
      await _choose(state, ['white_legend_stone']);

      expect(_ids(state.hand.cards)..sort(), [
        'mon_van_001',
        'silver_eyes_dragon',
        'silver_eyes_dragon',
        'silver_eyes_dragon'
      ]);
      expect(_ids(state.deck.cards), ['mon_warrior_001']);
    });
  });
}
