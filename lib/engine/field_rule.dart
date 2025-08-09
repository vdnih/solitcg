import 'types.dart';
import 'stack.dart';

class FieldRule {
  static GameResult playField(GameState state, CardInstance fieldCard) {
    if (fieldCard.card.type != CardType.field) {
      return GameResult.failure('Card is not a field card');
    }

    final logs = <String>[];
    
    final oldField = state.currentField;
    
    state.field.clear();
    state.field.add(fieldCard);
    logs.add('Set field: ${fieldCard.card.name}');
    
    for (final ability in fieldCard.card.abilities) {
      if (ability.when == TriggerWhen.onPlay) {
        TriggerStack.enqueueAbility(state, fieldCard, ability);
        logs.add('Queued on_play trigger for ${fieldCard.card.name}');
      }
    }
    
    if (oldField != null) {
      state.grave.add(oldField);
      logs.add('Old field ${oldField.card.name} destroyed and sent to grave');
      
      for (final ability in oldField.card.abilities) {
        if (ability.when == TriggerWhen.onDestroy) {
          TriggerStack.enqueueAbility(state, oldField, ability);
          logs.add('Queued on_destroy trigger for ${oldField.card.name}');
        }
      }
    }
    
    return GameResult.success(logs: logs);
  }

  static GameResult playCard(GameState state, CardInstance card) {
    final logs = <String>[];
    
    switch (card.card.type) {
      case CardType.field:
        return playField(state, card);
        
      case CardType.spell:
        state.spellsCastThisTurn++;
        logs.add('Cast spell: ${card.card.name}');
        state.grave.add(card);
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onPlay) {
            TriggerStack.enqueueAbility(state, card, ability);
          }
        }
        break;
        
      case CardType.monster:
        if (state.hasField) {
          return GameResult.failure('Cannot summon monster: field occupied');
        }
        
        state.field.add(card);
        logs.add('Summoned monster: ${card.card.name}');
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onPlay || ability.when == TriggerWhen.onEnter) {
            TriggerStack.enqueueAbility(state, card, ability);
          }
        }
        break;
        
      case CardType.artifact:
        state.field.add(card);
        logs.add('Played artifact: ${card.card.name}');
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onPlay) {
            TriggerStack.enqueueAbility(state, card, ability);
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

    final card = state.hand.removeAt(handIndex);
    if (card == null) {
      return GameResult.failure('No card at index $handIndex');
    }

    return playCard(state, card);
  }
}