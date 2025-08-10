import 'dart:collection';
import 'types.dart';
import 'ops.dart';

/// トリガーキューを管理し、効果解決を行うユーティリティ。
class TriggerStack {
  /// トリガーをキューに追加し、ログを記録する。
  static void enqueueTrigger(GameState state, Trigger trigger) {
    state.triggerQueue.addLast(trigger);
    state.addToLog('Triggered: ${trigger.source.card.name} - ${_triggerWhenToString(trigger.ability.when)}');
  }

  /// アビリティからトリガーを生成しキューに追加する。
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

  /// キュー内のトリガーを順に解決する。
  /// ループ防止のため最大100回まで実行する。
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

  /// 単一のトリガーを解決する。
  static GameResult _resolveTrigger(GameState state, Trigger trigger) {
    final logs = <String>[];
    
    if (trigger.ability.pre != null && trigger.ability.pre!.isNotEmpty) {
      // すべての事前条件をチェック
      bool allPreConditionsMet = true;
      for (final condition in trigger.ability.pre!) {
        final conditionResult = ExpressionEvaluator.evaluate(state, condition);
        if (!conditionResult) {
          allPreConditionsMet = false;
          break;
        }
      }
      
      if (!allPreConditionsMet) {
        logs.add('Pre-condition failed, skipping effect');
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

  /// TriggerWhen をログ用の文字列に変換する。
  static String _triggerWhenToString(TriggerWhen when) {
    switch (when) {
      case TriggerWhen.onPlay:
        return 'on_play';
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
    }
  }
}

/// 文字列表現を評価して true/false を返す簡易式評価機。
class ExpressionEvaluator {
  /// 与えられた式を評価する。解析に失敗した場合は false を返す。
  static bool evaluate(GameState state, String expression) {
    try {
      return _parseExpression(state, expression.trim());
    } catch (e) {
      return false;
    }
  }

  /// シンプルな比較式を解析して評価する。
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
      case 'board.count':
        return state.board.count;
      case 'grave.count':
        return state.grave.count;
      case 'domain.exists':
        return state.hasDomain ? 1 : 0;
      case 'player.life':
        return state.playerLife;
      case 'opponent.life':
        return state.opponentLife;
      case 'spells_cast_this_turn':
        return state.spellsCastThisTurn;
      // Legacy support
      case 'field.exists':
        return state.board.isNotEmpty ? 1 : 0;
      case 'field.count':
        return state.board.count;
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

  /// 文字列の前後にあるクォートを取り除く。
  static String _removeQuotes(String text) {
    if ((text.startsWith("'") && text.endsWith("'")) || 
        (text.startsWith('"') && text.endsWith('"'))) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }
  
  /// count(type:'artifact', zone:'board:self') のような形式の式を評価する。
  static int _evaluateCountExpression(GameState state, String expr) {
    // count(type:'artifact', zone:'board:self') のような形式を処理
    try {
      // 正規表現よりも単純に文字列解析で処理する
      if (!expr.startsWith('count(') || !expr.endsWith(')')) {
        return 0;
      }
      
      final content = expr.substring(6, expr.length - 1).trim();
      final params = content.split(',').map((p) => p.trim()).toList();
      
      String? param1Type;
      String? param1Value;
      String? param2Type;
      String? param2Value;
      
      if (params.isNotEmpty) {
        final parts1 = params[0].split(':');
        if (parts1.length == 2) {
          param1Type = parts1[0].trim();
          // クォーテーション除去
          param1Value = _removeQuotes(parts1[1].trim());
        }
      }
      
      if (params.length > 1) {
        final parts2 = params[1].split(':');
        if (parts2.length == 2) {
          param2Type = parts2[0].trim();
          // クォーテーション除去
          param2Value = _removeQuotes(parts2[1].trim());
        }
      }
      
      // ゾーンとタイプ・タグをもとにカード数をカウント
      String? zoneStr;
      String? filterType;
      String? filterTag;
      
      if (param1Type == 'zone') {
        zoneStr = param1Value;
      } else if (param1Type == 'type') {
        filterType = param1Value;
      } else if (param1Type == 'tag') {
        filterTag = param1Value;
      }
      
      if (param2Type == 'zone') {
        zoneStr = param2Value;
      } else if (param2Type == 'type') {
        filterType = param2Value;
      } else if (param2Type == 'tag') {
        filterTag = param2Value;
      }
      
      // ゾーン指定がない場合はボードをデフォルトにする
      zoneStr ??= 'board:self';
      
      // ゾーン解析: 'board:self' のようにコロンで区切られている
      final zoneParts = zoneStr.split(':');
      final zoneName = zoneParts[0];
      // TODO: 将来的に相手のゾーンを参照する処理を実装する場合に使用
      // final zoneOwner = zoneParts.length > 1 ? zoneParts[1] : 'self';
      
      GameZone? zone;
      switch (zoneName) {
        case 'hand': zone = state.hand; break;
        case 'board': zone = state.board; break;
        case 'deck': zone = state.deck; break;
        case 'grave': zone = state.grave; break;
        case 'domain': zone = state.domain; break;
        case 'extra': zone = state.extra; break;
        case 'field': zone = state.board; break; // 後方互換性
      }
      
      if (zone == null) {
        return 0;
      }
      
      // フィルターを適用してカウント
      int count = 0;
      for (final card in zone.cards) {
        bool matches = true;
        
        if (filterType != null) {
          final cardType = card.card.type.toString().split('.').last;
          if (cardType != filterType) {
            matches = false;
          }
        }
        
        if (matches && filterTag != null) {
          if (!card.card.tags.contains(filterTag)) {
            matches = false;
          }
        }
        
        if (matches) {
          count++;
        }
      }
      
      return count;
    } catch (e) {
      return 0;
    }
  }
}