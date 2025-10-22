import '../../core/game_state.dart';
import '../models/card_data.dart';
import '../models/card_instance.dart';
import '../models/game_result.dart';
import './expression_evaluator.dart';
import './trigger_service.dart';

class FieldRule {
  static GameResult playDomain(GameState state, CardInstance domainCard) {
    if (domainCard.card.type != CardType.domain) {
      return GameResult.failure('Card is not a domain card');
    }

    final logs = <String>[];
    
    final oldDomain = state.currentDomain;
    
    state.domain.clear();
    state.domain.add(domainCard);
    logs.add('Set domain: ${domainCard.card.name}');
    
    for (final ability in domainCard.card.abilities) {
      if (ability.when == TriggerWhen.onPlay) {
        TriggerService.enqueueAbility(state, domainCard, ability);
        logs.add('Queued onPlay trigger for ${domainCard.card.name}');
      }
    }
    
    if (oldDomain != null) {
      state.grave.add(oldDomain);
      logs.add('Old domain ${oldDomain.card.name} destroyed and sent to grave');
      
      for (final ability in oldDomain.card.abilities) {
        if (ability.when == TriggerWhen.onDestroy) {
          TriggerService.enqueueAbility(state, oldDomain, ability);
          logs.add('Queued onDestroy trigger for ${oldDomain.card.name}');
        }
      }
    }
    
    return GameResult.success(logs: logs);
  }

  static GameResult playCard(GameState state, CardInstance card) {
    final logs = <String>[];
    
    switch (card.card.type) {
      case CardType.domain:
        return playDomain(state, card);
        
      case CardType.spell:
      case CardType.arcane:
        state.spellsCastThisTurn++;
        logs.add('Cast spell: ${card.card.name}');
        state.grave.add(card);
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onPlay) {
            TriggerService.enqueueAbility(state, card, ability);
          }
        }
        break;
        
      case CardType.monster:
      case CardType.ritual:
        state.board.add(card);
        logs.add('Summoned ${card.card.type.toString().split('.').last}: ${card.card.name}');
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onPlay) {
            TriggerService.enqueueAbility(state, card, ability);
          }
        }
        break;
        
      case CardType.artifact:
      case CardType.relic:
        state.board.add(card);
        logs.add('Played ${card.card.type.toString().split('.').last}: ${card.card.name}');
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onPlay) {
            TriggerService.enqueueAbility(state, card, ability);
          }
        }
        break;
        
      case CardType.equip:
        return GameResult.failure('Equip cards not fully implemented yet');
    }
    
    return GameResult.success(logs: logs);
  }

  static GameResult playCardFromHand(GameState state, int handIndex) {
    if (handIndex < 0 || handIndex >= state.hand.count) {
      return GameResult.failure('Invalid hand index: $handIndex');
    }

    final card = state.hand.cards[handIndex];

    // Check preconditions for onPlay abilities
    for (final ability in card.card.abilities) {
      if (ability.when == TriggerWhen.onPlay || ability.when == TriggerWhen.activated) {
        if (ability.pre != null) {
          for (final condition in ability.pre!) {
            if (!ExpressionEvaluator.evaluate(state, condition)) {
              return GameResult.failure('前提条件を満たしていないため発動できません');
            }
          }
        }
      }
    }

    final removedCard = state.hand.removeAt(handIndex);
    if (removedCard == null) {
      // This should not happen if the index is valid
      return GameResult.failure('Failed to remove card from hand');
    }

    return playCard(state, removedCard);
  }
}