import '../models/card_data.dart';
import '../models/deck.dart';
import '../models/deck_rules.dart';
import '../models/deck_validation_result.dart';

/// デッキのバリデーションを行うクラス
class DeckValidator {
  /// デッキが有効かどうかをチェック
  static Future<DeckValidationResult> validateDeck(Deck deck, List<CardData> allCards) async {
    final errors = <String>[];
    
    // カードIDとカードオブジェクトのマップを作成
    final cardMap = {for (var card in allCards) card.id: card};
    
    // カードの枚数をチェック
    if (deck.type == DeckType.main) {
      if (deck.cardCount < DeckRules.mainDeckMinCards) {
        errors.add('メインデッキは${DeckRules.mainDeckMinCards}枚以上必要です（現在: ${deck.cardCount}枚）');
      }
    } else if (deck.type == DeckType.extra) {
      if (deck.cardCount > DeckRules.extraDeckMaxCards) {
        errors.add('エクストラデッキは${DeckRules.extraDeckMaxCards}枚以下である必要があります（現在: ${deck.cardCount}枚）');
      }
    }
    
    // カードの重複チェック
    final cardCounts = <String, int>{};
    for (final cardId in deck.cardIds) {
      cardCounts[cardId] = (cardCounts[cardId] ?? 0) + 1;
    }
    
    for (final entry in cardCounts.entries) {
      final cardId = entry.key;
      final count = entry.value;
      
      // カードが存在するか確認
      final card = cardMap[cardId];
      if (card == null) {
        errors.add('存在しないカード: $cardId');
        continue;
      }
      
      // メインデッキの同一カード枚数制限
      if (deck.type == DeckType.main) {
        if (count > DeckRules.mainDeckSameCardLimit) {
          errors.add('${card.name}は${DeckRules.mainDeckSameCardLimit}枚までしか入れられません（現在: $count枚）');
        }
      }
      
      // エクストラデッキの同一カード枚数制限
      if (deck.type == DeckType.extra) {
        if (count > DeckRules.extraDeckSameCardLimit) {
          errors.add('エクストラデッキの${card.name}は${DeckRules.extraDeckSameCardLimit}枚までしか入れられません（現在: $count枚）');
        }
      }
      
      // エクストラデッキに入れられるカードタイプかチェック
      if (deck.type == DeckType.extra && !DeckRules.canBeInExtraDeck(card.type)) {
        errors.add('${card.name}はエクストラデッキに入れられないタイプのカードです');
      }
    }
    
    return DeckValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}