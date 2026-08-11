import '../../core/game_state.dart';
import '../models/card_data.dart';
import '../models/card_instance.dart';
import '../models/choice_request.dart';
import '../models/game_result.dart';
import './trigger_service.dart';
import './zone_resolver.dart';

/// プレイヤーが確定したカード選択を [GameState.choiceRequest] に適用するドメインロジック。
///
/// 選択の種類（discard/move/destroy）に応じてカードを移動させ、
/// 中断されていた残り effect があれば [TriggerService.runEffects] で再開する。
class ChoiceResolver {
  static GameResult applySelection(GameState state, List<CardInstance> selected) {
    final request = state.choiceRequest.value;
    if (request == null) return GameResult.success();

    final logs = <String>[];

    switch (request.type) {
      case ChoiceType.discard:
        for (final card in selected) {
          state.hand.remove(card);
          state.grave.add(card);
          for (final ability in card.card.abilities) {
            if (ability.when == TriggerWhen.onDiscard) {
              TriggerService.enqueueAbility(state, card, ability);
            }
          }
        }
        logs.add('Player discarded ${selected.length} card(s)');
      case ChoiceType.move:
        final destination = ZoneResolver.byName(state, request.targetZone ?? 'hand');
        final source = ZoneResolver.byName(state, request.sourceZone);
        if (source != null && destination != null) {
          for (final card in selected) {
            source.remove(card);
            destination.add(card);
          }
          logs.add('Player moved ${selected.length} card(s) to ${request.targetZone}');
        }
      case ChoiceType.destroy:
        for (final card in selected) {
          state.board.remove(card);
          state.grave.add(card);
          for (final ability in card.card.abilities) {
            if (ability.when == TriggerWhen.onDestroy) {
              TriggerService.enqueueAbility(state, card, ability);
            }
          }
        }
        logs.add('Player destroyed ${selected.length} card(s)');
    }

    final pendingEffects = request.pendingEffects;
    final sourceCard = request.sourceCard;
    state.choiceRequest.value = null;

    if (pendingEffects.isEmpty) {
      return GameResult.success(logs: logs);
    }

    final effectResult = TriggerService.runEffects(state, pendingEffects, source: sourceCard);
    logs.addAll(effectResult.logs);

    return GameResult(
      success: effectResult.success,
      awaitingChoice: effectResult.awaitingChoice,
      error: effectResult.error,
      logs: logs,
    );
  }
}
