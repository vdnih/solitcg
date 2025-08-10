import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/deck.dart';
import '../../providers/deck_provider.dart';
import '../../routes.dart';

/// デッキ選択画面
class DeckSelectorScreen extends ConsumerStatefulWidget {
  const DeckSelectorScreen({super.key});

  @override
  ConsumerState<DeckSelectorScreen> createState() => _DeckSelectorScreenState();
}

class _DeckSelectorScreenState extends ConsumerState<DeckSelectorScreen> {
  bool _isLoading = true;
  List<Deck> _mainDecks = [];
  List<Deck> _extraDecks = [];

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  // デッキデータの読み込み
  Future<void> _loadDecks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final decks = await DeckStorage.loadDecks();
      
      setState(() {
        _mainDecks = decks.decks.where((d) => d.type == DeckType.main).toList();
        _extraDecks = decks.decks.where((d) => d.type == DeckType.extra).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('デッキの読み込みに失敗しました'))
        );
      }
    }
  }

  // デッキの選択
  void _selectDeck(Deck deck) {
    ref.read(selectedDeckIdProvider.notifier).state = deck.id;
    
    // デッキビルダー画面へ遷移
    if (mounted) {
      AppRoutes.navigateTo(context, AppRoutes.deckBuilder);
    }
  }

  // デッキの削除
  Future<void> _deleteDeck(Deck deck) async {
    // 削除前に確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('デッキの削除'),
        content: Text('「${deck.name}」を削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      final collection = await DeckStorage.loadDecks();
      collection.removeDeck(deck.id);
      await DeckStorage.saveDecks(collection);
      
      // デッキリストを再読み込み
      _loadDecks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('デッキ選択'),
        actions: [
          // 新規デッキボタン
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // 選択中のデッキをクリア
              ref.read(selectedDeckIdProvider.notifier).state = null;
              
              // デッキビルダー画面へ遷移
              AppRoutes.navigateTo(context, AppRoutes.deckBuilder);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDecks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // メインデッキセクション
                    const Text(
                      'メインデッキ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_mainDecks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: Text('メインデッキがありません')),
                      )
                    else
                      ..._mainDecks.map((deck) => _buildDeckCard(deck)),
                    
                    const SizedBox(height: 32),
                    
                    // エクストラデッキセクション
                    const Text(
                      'エクストラデッキ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_extraDecks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: Text('エクストラデッキがありません')),
                      )
                    else
                      ..._extraDecks.map((deck) => _buildDeckCard(deck)),
                  ],
                ),
              ),
            ),
    );
  }

  // デッキカードウィジェット
  Widget _buildDeckCard(Deck deck) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          deck.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
            // 編集ボタン
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _selectDeck(deck),
            ),
            // 削除ボタン
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _deleteDeck(deck),
            ),
          ],
        ),
        onTap: () => _selectDeck(deck),
      ),
    );
  }
}