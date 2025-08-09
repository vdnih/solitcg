import 'dart:math';
import 'types.dart';
import 'stack.dart';

class OperationExecutor {
  static GameResult executeOperation(GameState state, EffectStep effect) {
    try {
      switch (effect.op) {
        case 'require':
          return _executeRequire(state, effect.params);
        case 'draw':
          return _executeDraw(state, effect.params);
        case 'discard':
          return _executeDiscard(state, effect.params);
        case 'search':
          return _executeSearch(state, effect.params);
        case 'move':
          return _executeMove(state, effect.params);
        case 'destroy':
          return _executeDestroy(state, effect.params);
        case 'win_if':
          return _executeWinIf(state, effect.params);
        case 'lose_if':
          return _executeLoseIf(state, effect.params);
        case 'mill':
          return _executeMill(state, effect.params);
        case 'summon':
          return _executeSummon(state, effect.params);
        case 'set_field':
          return _executeSetField(state, effect.params);
        default:
          return GameResult.failure('Unknown operation: ${effect.op}');
      }
    } catch (e) {
      return GameResult.failure('Operation error: ${e.toString()}');
    }
  }

  static GameResult _executeRequire(GameState state, Map<String, dynamic> params) {
    final expr = params['expr'] as String?;
    if (expr == null) {
      return GameResult.failure('require: missing expr parameter');
    }

    final result = ExpressionEvaluator.evaluate(state, expr);
    if (!result) {
      return GameResult.failure('Requirement not met: $expr', logs: ['Require failed: $expr']);
    }

    return GameResult.success(logs: ['Require passed: $expr']);
  }

  static GameResult _executeDraw(GameState state, Map<String, dynamic> params) {
    final count = params['count'] as int? ?? 1;
    final logs = <String>[];
    
    int drawn = 0;
    for (int i = 0; i < count && state.deck.isNotEmpty; i++) {
      final card = state.deck.removeAt(0);
      if (card != null) {
        state.hand.add(card);
        drawn++;
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onDraw) {
            TriggerStack.enqueueAbility(state, card, ability);
          }
        }
      }
    }

    logs.add('Drew $drawn cards');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeDiscard(GameState state, Map<String, dynamic> params) {
    final from = params['from'] as String? ?? 'hand';
    final count = params['count'] as int? ?? 1;
    final logs = <String>[];

    if (from != 'hand') {
      return GameResult.failure('discard: only supports from="hand" currently');
    }

    if (state.hand.count < count) {
      return GameResult.failure('Not enough cards to discard (need $count, have ${state.hand.count})');
    }

    for (int i = 0; i < count; i++) {
      final card = state.hand.removeAt(0);
      if (card != null) {
        state.grave.add(card);
        
        for (final ability in card.card.abilities) {
          if (ability.when == TriggerWhen.onDiscard) {
            TriggerStack.enqueueAbility(state, card, ability);
          }
        }
      }
    }

    logs.add('Discarded $count cards');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeSearch(GameState state, Map<String, dynamic> params) {
    final fromZone = params['from'] as String? ?? 'deck';
    final toZone = params['to'] as String? ?? 'hand';
    final filter = params['filter'] as Map<String, dynamic>? ?? {};
    final maxCount = params['max'] as int? ?? 1;
    final logs = <String>[];

    final source = _getZoneByName(state, fromZone);
    final destination = _getZoneByName(state, toZone);

    if (source == null || destination == null) {
      return GameResult.failure('Invalid zone in search operation');
    }

    final matchingCards = source.where((card) => _matchesFilter(card, filter)).toList();
    final cardsToMove = matchingCards.take(maxCount).toList();

    for (final card in cardsToMove) {
      source.remove(card);
      destination.add(card);
    }

    if (fromZone == 'deck') {
      _shuffleDeck(state);
    }

    logs.add('Searched $fromZone for ${cardsToMove.length} cards, added to $toZone');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeMove(GameState state, Map<String, dynamic> params) {
    final fromZone = params['from'] as String?;
    final toZone = params['to'] as String?;
    final target = params['target'] as String? ?? 'any';
    final count = params['count'] as int? ?? 1;
    final logs = <String>[];

    if (fromZone == null || toZone == null) {
      return GameResult.failure('move: missing from or to parameter');
    }

    final source = _getZoneByName(state, fromZone);
    final destination = _getZoneByName(state, toZone);

    if (source == null || destination == null) {
      return GameResult.failure('Invalid zone in move operation');
    }

    int moved = 0;
    for (int i = 0; i < count && source.isNotEmpty; i++) {
      CardInstance? card;
      
      switch (target) {
        case 'top':
          card = source.removeAt(0);
          break;
        case 'bottom':
          card = source.removeAt(source.count - 1);
          break;
        case 'any':
        default:
          card = source.removeAt(0);
          break;
      }

      if (card != null) {
        destination.add(card);
        moved++;
      }
    }

    logs.add('Moved $moved cards from $fromZone to $toZone');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeDestroy(GameState state, Map<String, dynamic> params) {
    final target = params['target'] as String? ?? 'field';
    final logs = <String>[];

    if (target == 'field' && state.hasField) {
      final fieldCard = state.field.removeAt(0)!;
      state.grave.add(fieldCard);
      
      for (final ability in fieldCard.card.abilities) {
        if (ability.when == TriggerWhen.onDestroy) {
          TriggerStack.enqueueAbility(state, fieldCard, ability);
        }
      }
      
      logs.add('Destroyed field card: ${fieldCard.card.name}');
      return GameResult.success(logs: logs);
    }

    return GameResult.failure('No valid target to destroy');
  }

  static GameResult _executeWinIf(GameState state, Map<String, dynamic> params) {
    final expr = params['expr'] as String?;
    if (expr == null) {
      return GameResult.failure('win_if: missing expr parameter');
    }

    final condition = ExpressionEvaluator.evaluate(state, expr);
    if (condition) {
      state.gameWon = true;
      return GameResult.success(logs: ['VICTORY: $expr']);
    }

    return GameResult.success(logs: ['Win condition not met: $expr']);
  }

  static GameResult _executeLoseIf(GameState state, Map<String, dynamic> params) {
    final expr = params['expr'] as String?;
    if (expr == null) {
      return GameResult.failure('lose_if: missing expr parameter');
    }

    final condition = ExpressionEvaluator.evaluate(state, expr);
    if (condition) {
      state.gameLost = true;
      return GameResult.success(logs: ['DEFEAT: $expr']);
    }

    return GameResult.success(logs: ['Lose condition not met: $expr']);
  }

  static GameResult _executeMill(GameState state, Map<String, dynamic> params) {
    final count = params['count'] as int? ?? 1;
    final logs = <String>[];
    
    int milled = 0;
    for (int i = 0; i < count && state.deck.isNotEmpty; i++) {
      final card = state.deck.removeAt(0);
      if (card != null) {
        state.grave.add(card);
        milled++;
      }
    }

    logs.add('Milled $milled cards');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeSummon(GameState state, Map<String, dynamic> params) {
    return GameResult.failure('summon: not implemented yet');
  }

  static GameResult _executeSetField(GameState state, Map<String, dynamic> params) {
    return GameResult.failure('set_field: not implemented yet');
  }

  static GameZone? _getZoneByName(GameState state, String zoneName) {
    switch (zoneName.toLowerCase()) {
      case 'hand':
        return state.hand;
      case 'deck':
        return state.deck;
      case 'field':
        return state.field;
      case 'grave':
        return state.grave;
      case 'banish':
        return state.banish;
      default:
        return null;
    }
  }

  static bool _matchesFilter(CardInstance card, Map<String, dynamic> filter) {
    if (filter.containsKey('type')) {
      final type = filter['type'] as String;
      if (card.card.type.toString().split('.').last != type) {
        return false;
      }
    }

    if (filter.containsKey('tag')) {
      final tag = filter['tag'] as String;
      if (!card.card.tags.contains(tag)) {
        return false;
      }
    }

    if (filter.containsKey('name')) {
      final name = filter['name'] as String;
      if (card.card.name != name) {
        return false;
      }
    }

    return true;
  }

  static void _shuffleDeck(GameState state) {
    final random = Random();
    for (int i = state.deck.count - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = state.deck.cards[i];
      state.deck.cards[i] = state.deck.cards[j];
      state.deck.cards[j] = temp;
    }
  }
}