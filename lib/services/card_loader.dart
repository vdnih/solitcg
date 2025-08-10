import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../engine/types.dart';
import '../engine/loader.dart';

/// カードローダーサービス
/// ゲームで使用する全カードデータの読み込みを担当
class CardLoaderService {
  static const String indexPath = 'assets/cards/index.yaml';
  static const String cardsPath = 'assets/cards/';

  // すべてのカードをロードする
  static Future<List<Card>> loadAllCards() async {
    try {
      // CardLoaderクラスの機能を使用してカードを読み込む
      final cards = await CardLoader.loadAllCards();
      
      if (kDebugMode) {
        print('${cards.length}枚のカードをロードしました');
      }
      
      return cards;
      
    } catch (e) {
      if (kDebugMode) {
        print('カードローダーエラー: $e');
      }
      return [];
    }
  }
  
  // カードIDからカードを検索
  static Card? findCardById(List<Card> cards, String id) {
    try {
      return cards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }
}