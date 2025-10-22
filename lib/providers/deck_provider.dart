import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/card_data.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/deck_validation_result.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../../domain/services/deck_validator.dart';

// デッキコレクション用のプロバイダー
final deckCollectionProvider = StateNotifierProvider<DeckCollectionNotifier, DeckCollection>(
  (ref) => DeckCollectionNotifier(),
);

// 全カードリスト用のプロバイダー
final allCardsProvider = FutureProvider<List<CardData>>(
  (ref) => CardRepository.loadAllCards(),
);

// 現在選択中のデッキID用のプロバイダー
final selectedDeckIdProvider = StateProvider<String?>(
  (ref) => null,
);

// 現在選択中のデッキを提供するプロバイダー
final selectedDeckProvider = Provider<Deck?>(
  (ref) {
    final collection = ref.watch(deckCollectionProvider);
    final selectedId = ref.watch(selectedDeckIdProvider);
    
    if (selectedId == null) {
      return collection.decks.isNotEmpty ? collection.decks.first : null;
    }
    
    return collection.getDeck(selectedId);
  },
);

// 現在のデッキの検証結果を提供するプロバイダー
final deckValidationProvider = FutureProvider<DeckValidationResult?>(
  (ref) async {
    final deck = ref.watch(selectedDeckProvider);
    final cards = await ref.watch(allCardsProvider.future);
    
    if (deck == null) return null;
    return DeckValidator.validateDeck(deck, cards);
  },
);

// デッキコレクションのNotifier
class DeckCollectionNotifier extends StateNotifier<DeckCollection> {
  DeckCollectionNotifier() : super(DeckCollection()) {
    loadDecks();
  }
  
  // デッキコレクションの読み込み
  Future<void> loadDecks() async {
    state = await DeckRepository.loadDecks();
  }
  
  // デッキの追加
  void addDeck(Deck deck) {
    final newDecks = [...state.decks, deck];
    state = DeckCollection()..decks = newDecks;
    _saveDecks();
  }
  
  // デッキの更新
  void updateDeck(Deck deck) {
    final newDecks = state.decks.map((d) => d.id == deck.id ? deck : d).toList();
    state = DeckCollection()..decks = newDecks;
    _saveDecks();
  }
  
  // デッキの削除
  void removeDeck(String deckId) {
    final newDecks = state.decks.where((d) => d.id != deckId).toList();
    state = DeckCollection()..decks = newDecks;
    _saveDecks();
  }
  
  // デッキのカードを追加
  void addCardToDeck(String deckId, String cardId) {
    final newDecks = state.decks.map((deck) {
      if (deck.id == deckId) {
        final newCardIds = [...deck.cardIds, cardId];
        return Deck(id: deck.id, name: deck.name, type: deck.type, cardIds: newCardIds);
      }
      return deck;
    }).toList();
    state = DeckCollection()..decks = newDecks;
    _saveDecks();
  }
  
  // デッキのカードを削除
  void removeCardFromDeck(String deckId, String cardId) {
    final newDecks = state.decks.map((deck) {
      if (deck.id == deckId) {
        final newCardIds = [...deck.cardIds];
        // 最初に見つかったカードIDのみを削除
        final index = newCardIds.indexOf(cardId);
        if (index != -1) {
          newCardIds.removeAt(index);
        }
        return Deck(id: deck.id, name: deck.name, type: deck.type, cardIds: newCardIds);
      }
      return deck;
    }).toList();
    state = DeckCollection()..decks = newDecks;
    _saveDecks();
  }
  
  // デッキの保存
  Future<void> _saveDecks() async {
    await DeckRepository.saveDecks(state);
  }
  
  // デフォルトデッキの作成
  Future<void> createDefaultDecks(List<CardData> allCards) async {
    final defaultCollection = await DeckRepository.createDefaultDecks(allCards);
    state = defaultCollection;
    _saveDecks();
  }
}
