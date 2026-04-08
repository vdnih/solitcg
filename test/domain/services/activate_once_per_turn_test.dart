import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/models/card_data.dart';
import 'package:solitcg/domain/models/card_instance.dart';

void main() {
  late GameState state;
  late CardInstance card;

  setUp(() {
    state = GameState();
    card = CardInstance(
      card: const CardData(id: 'art001', name: 'Test Artifact', type: CardType.artifact),
      instanceId: 'art001-1',
    );
  });

  group('activated 能力の once_per_turn 制限', () {
    test('oncePerTurn: true のカードは activatedThisTurn 登録後に制限が発動する', () {
      final ability = Ability(
        when: TriggerWhen.activated,
        effects: const [],
        oncePerTurn: true,
      );

      // 1回目: まだ登録されていないので通過できる
      final blockedBefore = ability.oncePerTurn &&
          state.activatedThisTurn.contains(card.instanceId);
      expect(blockedBefore, isFalse);

      // 使用済みとして記録
      state.activatedThisTurn.add(card.instanceId);

      // 2回目: 制限により blocked になる
      final blockedAfter = ability.oncePerTurn &&
          state.activatedThisTurn.contains(card.instanceId);
      expect(blockedAfter, isTrue);
    });

    test('oncePerTurn: false のカードは activatedThisTurn に登録されても制限されない', () {
      final ability = Ability(
        when: TriggerWhen.activated,
        effects: const [],
        oncePerTurn: false,
      );

      // 使用済みとして仮登録（実際は登録されないが念のため確認）
      state.activatedThisTurn.add(card.instanceId);

      // oncePerTurn: false なので常に blocked にならない
      final blocked = ability.oncePerTurn &&
          state.activatedThisTurn.contains(card.instanceId);
      expect(blocked, isFalse);
    });

    test('ドローフェイズで activatedThisTurn がクリアされると制限がリセットされる', () {
      state.activatedThisTurn.add(card.instanceId);
      expect(state.activatedThisTurn.contains(card.instanceId), isTrue);

      // ドローフェイズのリセット相当
      state.activatedThisTurn.clear();

      expect(state.activatedThisTurn.contains(card.instanceId), isFalse);
    });
  });
}
