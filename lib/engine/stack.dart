import 'dart:collection';
import 'types.dart';
import 'ops.dart';

class TriggerStack {
  static void enqueueTrigger(GameState state, Trigger trigger) {
    state.triggerQueue.addLast(trigger);
    state.addToLog('Triggered: ${trigger.source.card.name} - ${_triggerWhenToString(trigger.ability.when)}');
  }

  static void enqueueAbility(GameState state, CardInstance source, Ability ability, {Map<String, dynamic>? context}) {
    final trigger = Trigger(
      id: 'trigger_${DateTime.now().millisecondsSinceEpoch}',
      source: source,
      ability: ability,
      order: state.getNextTriggerOrder(),
      context: context ?? {},
    );
    enqueueTrigger(state, trigger);
  }

  static GameResult resolveAll(GameState state) {
    final logs = <String>[];
    int iterations = 0;
    const maxIterations = 100;

    while (state.triggerQueue.isNotEmpty && iterations < maxIterations) {
      iterations++;
      
      if (state.isGameOver) {
        break;
      }

      final trigger = state.triggerQueue.removeFirst();
      logs.add('Resolving: ${trigger.source.card.name}');
      
      final result = _resolveTrigger(state, trigger);
      logs.addAll(result.logs);
      
      if (!result.success) {
        logs.add('Effect failed: ${result.error}');
      }
    }

    if (iterations >= maxIterations) {
      return GameResult.failure('Maximum iterations reached (infinite loop protection)', logs: logs);
    }

    return GameResult.success(logs: logs);
  }

  static GameResult _resolveTrigger(GameState state, Trigger trigger) {
    final logs = <String>[];
    
    if (trigger.ability.condition != null) {
      final conditionResult = ExpressionEvaluator.evaluate(state, trigger.ability.condition!);
      if (!conditionResult) {
        logs.add('Condition failed, skipping effect');
        return GameResult.success(logs: logs);
      }
    }

    for (final effect in trigger.ability.effects) {
      final result = OperationExecutor.executeOperation(state, effect);
      logs.addAll(result.logs);
      
      if (!result.success) {
        logs.add('Effect step failed: ${effect.op} - ${result.error}');
        return GameResult.failure('Effect execution failed', logs: logs);
      }
      
      if (state.isGameOver) {
        break;
      }
    }

    return GameResult.success(logs: logs);
  }

  static String _triggerWhenToString(TriggerWhen when) {
    switch (when) {
      case TriggerWhen.onPlay:
        return 'on_play';
      case TriggerWhen.onEnter:
        return 'on_enter';
      case TriggerWhen.onDestroy:
        return 'on_destroy';
      case TriggerWhen.static:
        return 'static';
      case TriggerWhen.activated:
        return 'activated';
      case TriggerWhen.onDraw:
        return 'on_draw';
      case TriggerWhen.onDiscard:
        return 'on_discard';
      case TriggerWhen.onFieldSet:
        return 'on_field_set';
    }
  }
}

class ExpressionEvaluator {
  static bool evaluate(GameState state, String expression) {
    try {
      return _parseExpression(state, expression.trim());
    } catch (e) {
      return false;
    }
  }

  static bool _parseExpression(GameState state, String expr) {
    if (expr.contains('>=')) {
      final parts = expr.split('>=').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        final left = _evaluateValue(state, parts[0]);
        final right = _evaluateValue(state, parts[1]);
        return left >= right;
      }
    }
    
    if (expr.contains('<=')) {
      final parts = expr.split('<=').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        final left = _evaluateValue(state, parts[0]);
        final right = _evaluateValue(state, parts[1]);
        return left <= right;
      }
    }
    
    if (expr.contains('>')) {
      final parts = expr.split('>').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        final left = _evaluateValue(state, parts[0]);
        final right = _evaluateValue(state, parts[1]);
        return left > right;
      }
    }
    
    if (expr.contains('<')) {
      final parts = expr.split('<').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        final left = _evaluateValue(state, parts[0]);
        final right = _evaluateValue(state, parts[1]);
        return left < right;
      }
    }
    
    if (expr.contains('==')) {
      final parts = expr.split('==').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        final left = _evaluateValue(state, parts[0]);
        final right = _evaluateValue(state, parts[1]);
        return left == right;
      }
    }
    
    if (expr.contains('!=')) {
      final parts = expr.split('!=').map((e) => e.trim()).toList();
      if (parts.length == 2) {
        final left = _evaluateValue(state, parts[0]);
        final right = _evaluateValue(state, parts[1]);
        return left != right;
      }
    }

    return _evaluateValue(state, expr) > 0;
  }

  static int _evaluateValue(GameState state, String expr) {
    switch (expr) {
      case 'hand.count':
        return state.hand.count;
      case 'deck.count':
        return state.deck.count;
      case 'grave.count':
        return state.grave.count;
      case 'field.exists':
        return state.hasField ? 1 : 0;
      case 'spells_cast_this_turn':
        return state.spellsCastThisTurn;
      default:
        if (int.tryParse(expr) != null) {
          return int.parse(expr);
        }
        if (expr.startsWith('count(')) {
          return _evaluateCountExpression(state, expr);
        }
        return 0;
    }
  }

  static int _evaluateCountExpression(GameState state, String expr) {
    return 0;
  }
}