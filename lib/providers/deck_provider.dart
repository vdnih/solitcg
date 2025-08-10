import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deck.dart';
import '../engine/types.dart' as game_types;
import '../services/card_loader.dart';

// デッキコレクション用のプロバイダー
final deckCollectionProvider = StateNotifierProvider<DeckCollectionNotifier, DeckCollection>(
  (ref) => DeckCollectionNotifier(),
);

// 全カードリスト用のプロバイダー
final allCardsProvider = FutureProvider<List<game_types.Card>>(
  (ref) => CardLoaderService.loadAllCards(),
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
    _loadDecks();
  }
  
  // デッキコレクションの読み込み
  Future<void> _loadDecks() async {
    final collection = await DeckStorage.loadDecks();
    state = collection;
  }
  
  // デッキの追加
  void addDeck(Deck deck) {
    state.addDeck(deck);
    _saveDecks();
  }
  
  // デッキの更新
  void updateDeck(Deck deck) {
    final index = state.decks.indexWhere((d) => d.id == deck.id);
    if (index >= 0) {
      final newDecks = [...state.decks];
      newDecks[index] = deck;
      state = DeckCollection()..decks = newDecks;
      _saveDecks();
    }
  }
  
  // デッキの削除
  void removeDeck(String deckId) {
    if (state.removeDeck(deckId)) {
      state = DeckCollection()..decks = [...state.decks];
      _saveDecks();
    }
  }
  
  // デッキのカードを追加
  void addCardToDeck(String deckId, String cardId) {
    final deck = state.getDeck(deckId);
    if (deck != null) {
      deck.addCard(cardId);
      state = DeckCollection()..decks = [...state.decks];
      _saveDecks();
    }
  }
  
  // デッキのカードを削除
  void removeCardFromDeck(String deckId, String cardId) {
    final deck = state.getDeck(deckId);
    if (deck != null && deck.removeCard(cardId)) {
      state = DeckCollection()..decks = [...state.decks];
      _saveDecks();
    }
  }
  
  // デッキの保存
  Future<void> _saveDecks() async {
    await DeckStorage.saveDecks(state);
  }
  
  // デフォルトデッキの作成
  Future<void> createDefaultDecks(List<game_types.Card> allCards) async {
    final defaultCollection = await DeckStorage.createDefaultDecks(allCards);
    state = defaultCollection;
    _saveDecks();
  }
}