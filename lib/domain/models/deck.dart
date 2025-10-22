/// デッキの種類
enum DeckType {
  main,    // メインデッキ
  extra,   // エクストラデッキ
}

/// デッキを表すクラス
class Deck {
  String id;                     // デッキID
  String name;                   // デッキ名
  DeckType type;                 // デッキタイプ
  List<String> cardIds = [];     // カードIDのリスト
  
  Deck({
    required this.id,
    required this.name,
    required this.type,
    List<String>? cardIds,
  }) : cardIds = cardIds ?? [];
  
  /// デッキ内のカード枚数
  int get cardCount => cardIds.length;
  
  /// カードを追加
  void addCard(String cardId) {
    cardIds.add(cardId);
  }
  
  /// カードを削除
  bool removeCard(String cardId) {
    int index = cardIds.indexOf(cardId);
    if (index >= 0) {
      cardIds.removeAt(index);
      return true;
    }
    return false;
  }
  
  /// カードが何枚入っているか
  int countCard(String cardId) {
    return cardIds.where((id) => id == cardId).length;
  }
  
  /// JSON形式に変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'cardIds': cardIds,
    };
  }
  
  /// JSONからデッキを生成
  static Deck fromJson(Map<String, dynamic> json) {
    DeckType deckType;
    if (json['type'] == 'main') {
      deckType = DeckType.main;
    } else if (json['type'] == 'extra') {
      deckType = DeckType.extra;
    } else {
      deckType = DeckType.main;
    }
    
    return Deck(
      id: json['id'],
      name: json['name'],
      type: deckType,
      cardIds: List<String>.from(json['cardIds']),
    );
  }
}

/// プレイヤーのデッキコレクションを管理するクラス
class DeckCollection {
  List<Deck> decks = [];
  
  /// デッキを追加
  void addDeck(Deck deck) {
    decks.add(deck);
  }
  
  /// デッキを削除
  bool removeDeck(String deckId) {
    int index = decks.indexWhere((deck) => deck.id == deckId);
    if (index >= 0) {
      decks.removeAt(index);
      return true;
    }
    return false;
  }
  
  /// デッキを検索
  Deck? getDeck(String deckId) {
    try {
      return decks.firstWhere((deck) => deck.id == deckId);
    } catch (e) {
      return null;
    }
  }
  
  /// JSON形式に変換
  Map<String, dynamic> toJson() {
    return {
      'decks': decks.map((deck) => deck.toJson()).toList(),
    };
  }
  
  /// JSONからコレクションを生成
  static DeckCollection fromJson(Map<String, dynamic> json) {
    DeckCollection collection = DeckCollection();
    
    if (json['decks'] != null) {
      for (var deckJson in json['decks']) {
        collection.decks.add(Deck.fromJson(deckJson));
      }
    }
    
    return collection;
  }
}
