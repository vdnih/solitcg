import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../engine/types.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:universal_html/html.dart' as html;

/// デッキの種類
enum DeckType {
  main,    // メインデッキ
  extra,   // エクストラデッキ
}

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

/// デッキバリデーション結果
class DeckValidationResult {
  final bool isValid;
  final List<String> errors;
  
  DeckValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

/// デッキの保存と読み込みを行うクラス
class DeckStorage {
  static const String deckFileName = 'decks.json';
  static const String localStorageKey = 'solitcg_decks';
  
  /// デッキコレクションを保存
  static Future<bool> saveDecks(DeckCollection collection) async {
    try {
      final jsonData = jsonEncode(collection.toJson());
      
      if (kIsWeb) {
        // Webの場合はローカルストレージに保存
        html.window.localStorage[localStorageKey] = jsonData;
      } else {
        // ネイティブの場合はファイルに保存
        final directory = await path_provider.getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$deckFileName');
        await file.writeAsString(jsonData);
      }
      
      if (kDebugMode) {
        print('デッキを保存しました');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('デッキ保存エラー: $e');
      }
      return false;
    }
  }
  
  /// デッキコレクションを読み込み
  static Future<DeckCollection> loadDecks() async {
    try {
      String? jsonData;
      
      if (kIsWeb) {
        // Webの場合はローカルストレージから読み込み
        jsonData = html.window.localStorage[localStorageKey];
      } else {
        // ネイティブの場合はファイルから読み込み
        final directory = await path_provider.getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$deckFileName');
        
        if (await file.exists()) {
          jsonData = await file.readAsString();
        }
      }
      
      if (jsonData != null && jsonData.isNotEmpty) {
        final Map<String, dynamic> decodedJson = jsonDecode(jsonData);
        return DeckCollection.fromJson(decodedJson);
      }
      
      // デフォルトのコレクションを返す
      return DeckCollection();
    } catch (e) {
      if (kDebugMode) {
        print('デッキ読み込みエラー: $e');
      }
      return DeckCollection();
    }
  }
  
  /// デフォルトのデッキを作成
  static Future<DeckCollection> createDefaultDecks(List<Card> allCards) async {
    final collection = DeckCollection();
    
    // 利用可能なカードを種類別に分類
    final monsterCards = allCards.where((c) => 
      c.type == CardType.monster || c.type == CardType.ritual).toList();
    final spellCards = allCards.where((c) => 
      c.type == CardType.spell || c.type == CardType.arcane).toList();
    final artifactCards = allCards.where((c) => 
      c.type == CardType.artifact || c.type == CardType.relic).toList();
    
    if (monsterCards.isNotEmpty && spellCards.isNotEmpty) {
      // スターターデッキの作成
      final mainDeck = Deck(
        id: 'starter_main', 
        name: 'スターターデッキ', 
        type: DeckType.main
      );
      
      // モンスターカードをいくつか追加
      for (int i = 0; i < monsterCards.length && i < 10; i++) {
        // 基本的なカードは4枚ずつ入れる
        for (int j = 0; j < 4; j++) {
          mainDeck.addCard(monsterCards[i].id);
        }
      }
      
      // 魔法カードを追加
      for (int i = 0; i < spellCards.length && i < 5; i++) {
        for (int j = 0; j < 2; j++) {
          mainDeck.addCard(spellCards[i].id);
        }
      }
      
      // アーティファクトカードを追加
      if (artifactCards.isNotEmpty) {
        for (int j = 0; j < 2 && j < artifactCards.length; j++) {
          mainDeck.addCard(artifactCards[j].id);
        }
      }
      
      collection.addDeck(mainDeck);
      
      // エクストラデッキも作成（利用可能なカードがあれば）
      final extraCards = allCards.where((c) => DeckRules.canBeInExtraDeck(c.type)).toList();
      if (extraCards.isNotEmpty) {
        final extraDeck = Deck(
          id: 'starter_extra',
          name: 'スターターエクストラ',
          type: DeckType.extra
        );
        
        // 利用可能なカードを最大枚数まで追加
        for (int i = 0; i < extraCards.length && i < DeckRules.extraDeckMaxCards; i++) {
          extraDeck.addCard(extraCards[i].id);
        }
        
        collection.addDeck(extraDeck);
      }
    }
    
    return collection;
  }
}

/// デッキのバリデーションを行うクラス
class DeckValidator {
  /// デッキが有効かどうかをチェック
  static Future<DeckValidationResult> validateDeck(Deck deck, List<Card> allCards) async {
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