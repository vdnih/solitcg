import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:universal_html/html.dart' as html;

import '../../domain/models/card_data.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/deck_rules.dart';

/// デッキの保存と読み込みを行うリポジトリクラス
class DeckRepository {
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
  static Future<DeckCollection> createDefaultDecks(List<CardData> allCards) async {
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