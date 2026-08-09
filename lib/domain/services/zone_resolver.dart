import '../../core/game_state.dart';
import '../models/game_zone.dart';

/// ゾーン名の文字列から [GameZone] を解決する共通ヘルパー。
///
/// `operation_executor.dart` / `tcg_game.dart` / `expression_evaluator.dart` に
/// 重複していたゾーン名解決ロジックを集約する。
class ZoneResolver {
  static GameZone? byName(GameState state, String? name) {
    if (name == null) return null;
    switch (name.toLowerCase()) {
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
      // 後方互換性のためのレガシーゾーン名
      case 'field':
        return state.board;
      default:
        return null;
    }
  }
}
