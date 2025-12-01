import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/deck.dart';
import '../../providers/deck_provider.dart';
import '../../routes.dart';

/// デッキ選択画面
class DeckSelectorScreen extends ConsumerWidget {
  final bool isSelectionMode;

  const DeckSelectorScreen({
    super.key,
    this.isSelectionMode = false,
  });

  // デッキの選択処理
  void _selectDeck(BuildContext context, WidgetRef ref, Deck deck) {
    if (isSelectionMode) {
      // ゲーム開始モードの場合、ゲーム画面へ遷移
      Navigator.pushNamed(
        context,
        AppRoutes.game,
        arguments: deck,
      );
    } else {
      // 編集モードの場合、デッキビルダーへ遷移
      ref.read(selectedDeckIdProvider.notifier).state = deck.id;
      AppRoutes.navigateTo(context, AppRoutes.deckBuilder);
    }
  }

  // デッキの削除処理
  void _deleteDeck(BuildContext context, WidgetRef ref, Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('デッキの削除'),
        content: Text('「${deck.name}」を削除してもよろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              ref.read(deckCollectionProvider.notifier).removeDeck(deck.id);
              Navigator.pop(context);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckCollection = ref.watch(deckCollectionProvider);
    final mainDecks = deckCollection.decks.where((d) => d.type == DeckType.main).toList();
    final extraDecks = deckCollection.decks.where((d) => d.type == DeckType.extra).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('デッキ選択'),
        actions: [
          // 新規デッキボタン
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // 新規デッキを作成し、ビルダー画面へ遷移
              final newDeck = Deck(
                id: 'deck_${DateTime.now().millisecondsSinceEpoch}',
                name: '新しいデッキ',
                type: DeckType.main,
              );
              ref.read(deckCollectionProvider.notifier).addDeck(newDeck);
              ref.read(selectedDeckIdProvider.notifier).state = newDeck.id;
              AppRoutes.navigateTo(context, AppRoutes.deckBuilder);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        // プロバイダーを再読み込みしてリストを更新
        onRefresh: () => ref.read(deckCollectionProvider.notifier).loadDecks(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // メインデッキセクション
              const Text('メインデッキ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (mainDecks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text('メインデッキがありません')),
                )
              else
                ...mainDecks.map((deck) => _buildDeckCard(context, ref, deck)),
              
              const SizedBox(height: 32),
              
              // エクストラデッキセクション
              const Text('エクストラデッキ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (extraDecks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text('エクストラデッキがありません')),
                )
              else
                ...extraDecks.map((deck) => _buildDeckCard(context, ref, deck)),
            ],
          ),
        ),
      ),
    );
  }

  // デッキカードウィジェット
  Widget _buildDeckCard(BuildContext context, WidgetRef ref, Deck deck) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(deck.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${deck.cardCount}枚のカード'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _selectDeck(context, ref, deck)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteDeck(context, ref, deck)),
          ],
        ),
        onTap: () => _selectDeck(context, ref, deck),
      ),
    );
  }
}