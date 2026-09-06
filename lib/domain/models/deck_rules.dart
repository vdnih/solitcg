import './card_data.dart';

/// デッキのカード制限ルール
class DeckRules {
  // メインデッキのルール
  static const int mainDeckMinCards = 40;
  static const int mainDeckSameCardLimit = 4;

  // エクストラデッキのルール
  static const int extraDeckMaxCards = 10;
  static const int extraDeckSameCardLimit = 1;

  // カードタイプがエクストラデッキに入れられるかどうか。
  // ADR-006 により旧 ritual/arcane/relic を廃止したため現在は対象タイプが無い。
  // ゾーンは維持し、対象タイプは将来追加する（docs/SPEC.md §9 参照）。
  static bool canBeInExtraDeck(CardType cardType) => false;
}
