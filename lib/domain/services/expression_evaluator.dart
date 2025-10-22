import '../../core/game_state.dart';
import '../models/game_zone.dart';

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
        case 'hand':
          zone = state.hand;
          break;
        case 'board':
          zone = state.board;
          break;
        case 'deck':
          zone = state.deck;
          break;
        case 'grave':
          zone = state.grave;
          break;
        case 'domain':
          zone = state.domain;
          break;
        case 'extra':
          zone = state.extra;
          break;
        case 'field':
          zone = state.board;
          break; // 後方互換性
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
