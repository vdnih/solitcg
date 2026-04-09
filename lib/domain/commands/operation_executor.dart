import 'dart:math';
import '../../core/game_state.dart';
import '../models/card_data.dart';
import '../models/card_instance.dart';
import '../models/choice_request.dart';
import '../models/game_result.dart';
import '../models/game_zone.dart';
import '../services/expression_evaluator.dart';
import '../services/trigger_service.dart';
import './draw_card_command.dart';

class OperationExecutor {
  static GameResult executeOperation(GameState state, EffectStep effect,
      {CardInstance? source}) {
    try {
      switch (effect.op) {
        case 'require':
          return _executeRequire(state, effect.params);
        case 'draw':
          final count = effect.params['count'] as int? ?? 1;
          return DrawCardCommand(count: count).execute(state);
        case 'discard':
          return _executeDiscard(state, effect.params);
        case 'search':
          return _executeSearch(state, effect.params);
        case 'move':
          return _executeMove(state, effect.params);
        case 'destroy':
          return _executeDestroy(state, effect.params);
        case 'win':
          return _executeWin(state);
        case 'win_if':
          return _executeWinIf(state, effect.params);
        case 'lose_if':
          return _executeLoseIf(state, effect.params);
        case 'mill':
          return _executeMill(state, effect.params);
        case 'summon':
          return _executeSummon(state, effect.params);
        case 'set_domain':
          return _executeSetDomain(state, effect.params);
        case 'add_counter':
          return _executeAddCounter(state, effect.params, source);
        case 'remove_counter':
          return _executeRemoveCounter(state, effect.params, source);
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

  static GameResult _executeDiscard(GameState state, Map<String, dynamic> params) {
    final from = params['from'] as String? ?? 'hand';
    final count = params['count'] as int? ?? 1;
    final filter = _parseFilter(params['filter']);
    final selection = params['selection'] as String?;
    final logs = <String>[];

    if (from != 'hand') {
      return GameResult.failure('discard: only supports from="hand" currently');
    }

    final candidates = state.hand.where((card) => _matchesFilter(card, filter)).toList();

    if (candidates.length < count) {
      return GameResult.failure(
        'Not enough cards to discard (need $count, matched ${candidates.length})',
      );
    }

    // selection: choose 指定、または filter 指定かつ候補が count より多い場合はプレイヤーに選択を委ねる
    if ((selection == 'choose' || filter.isNotEmpty) && candidates.length > count) {
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.discard,
        count: count,
        candidates: candidates,
        sourceZone: from,
        message: 'フィルタに一致するカードを$count枚選んでください',
      );
      return GameResult.pending(logs: ['Awaiting player choice for discard']);
    }

    // 自動選択（filter なし or ちょうど count 枚一致）
    for (final card in candidates.take(count).toList()) {
      state.hand.remove(card);
      state.grave.add(card);

      for (final ability in card.card.abilities) {
        if (ability.when == TriggerWhen.onDiscard) {
          TriggerService.enqueueAbility(state, card, ability);
        }
      }
    }

    logs.add('Discarded $count cards');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeSearch(GameState state, Map<String, dynamic> params) {
    final fromZone = params['from'] as String? ?? 'deck';
    final toZone = params['to'] as String? ?? 'hand';
    final filter = _parseFilter(params['filter']);
    final maxCount = params['max'] as int? ?? 1;
    final useRandom = params['random'] as bool? ?? false;
    final logs = <String>[];

    final source = _getZoneByName(state, fromZone);
    final destination = _getZoneByName(state, toZone);

    if (source == null || destination == null) {
      return GameResult.failure('Invalid zone in search operation');
    }

    final matchingCards = source.where((card) => _matchesFilter(card, filter)).toList();
    if (useRandom) {
      matchingCards.shuffle(Random());
    }
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
    final filter = _parseFilter(params['filter']);
    final selection = params['selection'] as String?;
    final logs = <String>[];

    if (fromZone == null || toZone == null) {
      return GameResult.failure('move: missing from or to parameter');
    }

    final source = _getZoneByName(state, fromZone);
    final destination = _getZoneByName(state, toZone);

    if (source == null || destination == null) {
      return GameResult.failure('Invalid zone in move operation');
    }

    final candidates = source.where((card) => _matchesFilter(card, filter)).toList();
    final ordered = (target == 'bottom') ? candidates.reversed.toList() : candidates;

    // selection: choose 指定、または filter 指定かつ候補が count より多い場合はプレイヤーに選択を委ねる
    if ((selection == 'choose' || filter.isNotEmpty) && ordered.length > count) {
      state.choiceRequest.value = ChoiceRequest(
        type: ChoiceType.move,
        count: count,
        candidates: ordered,
        sourceZone: fromZone,
        targetZone: toZone,
        message: '移動するカードを$count枚選んでください',
      );
      return GameResult.pending(logs: ['Awaiting player choice for move']);
    }

    int moved = 0;
    for (int i = 0; i < count && i < ordered.length; i++) {
      source.remove(ordered[i]);
      destination.add(ordered[i]);
      moved++;
    }

    logs.add('Moved $moved cards from $fromZone to $toZone');
    return GameResult.success(logs: logs);
  }

  static GameResult _executeDestroy(GameState state, Map<String, dynamic> params) {
    final target = params['target'] as String? ?? 'board';
    final filter = _parseFilter(params['filter']);
    final selection = params['selection'] as String?;
    final count = params['count'] as int? ?? 1;
    final logs = <String>[];

    if (target == 'domain' && state.hasDomain) {
      final domainCard = state.domain.removeAt(0)!;
      state.grave.add(domainCard);

      for (final ability in domainCard.card.abilities) {
        if (ability.when == TriggerWhen.onDestroy) {
          TriggerService.enqueueAbility(state, domainCard, ability);
        }
      }

      logs.add('Destroyed domain card: ${domainCard.card.name}');
      return GameResult.success(logs: logs);
    } else if (state.board.isNotEmpty) {
      final candidates = state.board.where((card) => _matchesFilter(card, filter)).toList();

      if (candidates.isEmpty) {
        return GameResult.failure('No valid target to destroy');
      }

      // selection: choose 指定、または filter 指定かつ候補が count より多い場合はプレイヤーに選択を委ねる
      if ((selection == 'choose' || filter.isNotEmpty) && candidates.length > count) {
        state.choiceRequest.value = ChoiceRequest(
          type: ChoiceType.destroy,
          count: count,
          candidates: candidates,
          sourceZone: 'board',
          message: '破壊するカードを$count枚選んでください',
        );
        return GameResult.pending(logs: ['Awaiting player choice for destroy']);
      }

      int destroyed = 0;
      for (int i = 0; i < count && i < candidates.length; i++) {
        final boardCard = candidates[i];
        state.board.remove(boardCard);
        state.grave.add(boardCard);

        for (final ability in boardCard.card.abilities) {
          if (ability.when == TriggerWhen.onDestroy) {
            TriggerService.enqueueAbility(state, boardCard, ability);
          }
        }
        destroyed++;
      }

      logs.add('Destroyed $destroyed cards from board');
      return GameResult.success(logs: logs);
    }

    return GameResult.failure('No valid target to destroy');
  }

  static GameResult _executeWin(GameState state) {
    state.gameWon = true;
    return GameResult.success(logs: ['VICTORY']);
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

  static GameResult _executeSetDomain(GameState state, Map<String, dynamic> params) {
    final cardId = params['card'] as String?;
    if (cardId == null) {
      return GameResult.failure('set_domain: missing card parameter');
    }

    // この部分は実際にはカードDBから該当カードを探す実装を行う
    return GameResult.failure('set_domain: implementation requires card database lookup');
  }

  static GameResult _executeAddCounter(
      GameState state, Map<String, dynamic> params, CardInstance? source) {
    if (source == null) {
      return GameResult.failure('add_counter: source card is required');
    }
    final key = params['key'] as String? ?? 'counter';
    final amount = params['amount'] as int? ?? 1;
    final current = (source.metadata[key] as int?) ?? 0;
    source.metadata[key] = current + amount;
    return GameResult.success(logs: [
      'Added $amount to counter "$key" on ${source.card.name} (now ${current + amount})'
    ]);
  }

  static GameResult _executeRemoveCounter(
      GameState state, Map<String, dynamic> params, CardInstance? source) {
    if (source == null) {
      return GameResult.failure('remove_counter: source card is required');
    }
    final key = params['key'] as String? ?? 'counter';
    source.metadata[key] = 0;
    return GameResult.success(
        logs: ['Reset counter "$key" on ${source.card.name} to 0']);
  }

  static GameZone? _getZoneByName(GameState state, String zoneName) {
    switch (zoneName.toLowerCase()) {
      case 'hand':
        return state.hand;
      case 'deck':
        return state.deck;
      case 'board':
        return state.board;
      case 'domain':
        return state.domain;
      case 'grave':
        return state.grave;
      case 'extra':
        return state.extra;
      // Handle legacy zone name for backward compatibility
      case 'field':
        return state.board;
      default:
        return null;
    }
  }

  /// YAML の filter パラメータを Map に変換する。
  /// YamlMap の場合も通常の Map として扱えるよう正規化する。
  static Map<String, dynamic> _parseFilter(dynamic filterParam) {
    if (filterParam == null) return {};
    if (filterParam is Map<String, dynamic>) return filterParam;
    if (filterParam is Map) {
      return filterParam.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
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
