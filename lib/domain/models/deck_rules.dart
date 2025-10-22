import './card_data.dart';

/// デッキのカード制限ルール
class DeckRules {
  // メインデッキのルール
  static const int mainDeckMinCards = 40;
  static const int mainDeckSameCardLimit = 4;
  
  // エクストラデッキのルール
  static const int extraDeckMaxCards = 10;
  static const int extraDeckSameCardLimit = 1;
  
  // カードタイプがエクストラデッキに入れられるかどうか
  static bool canBeInExtraDeck(CardType cardType) {
    return cardType == CardType.ritual || 
           cardType == CardType.arcane || 
           cardType == CardType.relic;
  }
}