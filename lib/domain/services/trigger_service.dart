import '../../core/game_state.dart';
import '../models/card_data.dart';
import '../models/card_instance.dart';
import '../models/game_result.dart';
import '../models/trigger.dart';
import '../commands/operation_executor.dart';
import './expression_evaluator.dart';

/// トリガーキューを管理し、効果解決を行うユーティリティ。
class TriggerService {
  /// トリガーをキューに追加し、ログを記録する。
  static void enqueueTrigger(GameState state, Trigger trigger) {
    state.triggerQueue.addLast(trigger);
    state.addToLog(
        'Triggered: ${trigger.source.card.name} - ${_triggerWhenToString(trigger.ability.when)}');
  }

  /// アビリティからトリガーを生成しキューに追加する。
  static void enqueueAbility(
      GameState state, CardInstance source, Ability ability,
      {Map<String, dynamic>? context}) {
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
  /// UI更新コールバックを挟みながら非同期で処理する。
  /// ループ防止のため最大100回まで実行する。
  static Future<GameResult> resolveAll(
      GameState state, Function onUpdate) async {
    final logs = <String>[];
    int iterations = 0;
    const maxIterations = 100;

    while (state.triggerQueue.isNotEmpty && iterations < maxIterations) {
      iterations++;

      if (state.isGameOver) {
        break;
      }

      // 解決前にUIを更新して待機
      onUpdate();
      await Future.delayed(const Duration(seconds: 1));

      final trigger = state.triggerQueue.removeFirst();
      logs.add('Resolving: ${trigger.source.card.name}');

      final result = _resolveTrigger(state, trigger);
      logs.addAll(result.logs);

      if (!result.success) {
        logs.add('Effect failed: ${result.error}');
      }

      // 解決後にもUIを更新
      onUpdate();
    }

    if (iterations >= maxIterations) {
      return GameResult.failure(
          'Maximum iterations reached (infinite loop protection)',
          logs: logs);
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
