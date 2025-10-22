import '../../core/game_state.dart';
import '../models/card_data.dart';
import '../models/game_result.dart';
import '../services/trigger_service.dart';
import './card_effect_command.dart';

/// カードを引く効果を表すコマンド。
class DrawCardCommand extends CardEffectCommand {
  /// 引くカードの枚数。
  final int count;

  DrawCardCommand({this.count = 1});

  @override
  GameResult execute(GameState state) {
    final logs = <String>[];
    int drawnCount = 0;

    // 指定された枚数、またはデッキがなくなるまでカードを引く
    for (int i = 0; i < count && state.deck.isNotEmpty; i++) {
      final card = state.deck.removeAt(0);
      if (card != null) {
        state.hand.add(card);
        drawnCount++;

        // ドロー時に発動するトリガーをチェックし、キューに追加
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onDraw) {
            TriggerService.enqueueAbility(state, card, ability);
          }
        }
      }
    }

    if (drawnCount > 0) {
      logs.add('Player drew $drawnCount card(s).');
    }

    return GameResult.success(logs: logs);
  }
}
