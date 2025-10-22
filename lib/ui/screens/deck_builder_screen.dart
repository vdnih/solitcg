import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/card_data.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/deck_rules.dart';
import '../../providers/deck_provider.dart';
import '../widgets/card_detail_dialog.dart';
import '../widgets/tag_selector_dialog.dart';

class DeckBuilderScreen extends ConsumerWidget {
  const DeckBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDeck = ref.watch(selectedDeckProvider);
    final allCards = ref.watch(allCardsProvider);
    final validationResult = ref.watch(deckValidationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedDeck?.name ?? 'デッキビルダー'),
        actions: [
          if (selectedDeck != null)
            ..._buildAppBarActions(context, ref, selectedDeck),
        ],
      ),
      body: allCards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
        data: (cards) {
          if (selectedDeck == null) {
            return const Center(child: Text('デッキが選択されていません。デッキ選択画面からデッキを選ぶか、新規作成してください。'));
          }
          return Column(
            children: [
              // デッキ検証結果
              validationResult.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, stack) => Container(), // エラーは握りつぶす
                data: (result) {
                  if (result == null) return Container();
                  return Container(
                    color: result.isValid ? Colors.green[100] : Colors.red[100],
                    padding: const EdgeInsets.all(8.0),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.isValid ? 'デッキは有効です' : 'デッキは無効です',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: result.isValid ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                        if (!result.isValid)
                          ...result.errors.map((error) => Text('• $error')),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: Row(
                  children: [
                    // デッキ内容表示 (左側)
                    Expanded(
                      flex: 2,
                      child: _DeckContentView(deck: selectedDeck, allCards: cards),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    // カードコレクション表示 (右側)
                    Expanded(
                      flex: 3,
                      child: _CardCollectionView(deck: selectedDeck, allCards: cards),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, WidgetRef ref, Deck deck) {
    return [
      // デッキタイプ切り替え
      DropdownButton<DeckType>(
        value: deck.type,
        items: DeckType.values.map((type) {
          String label = type == DeckType.main ? 'メイン' : 'エクストラ';
          return DropdownMenuItem(value: type, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(label),
          ));
        }).toList(),
        onChanged: (type) {
          if (type != null && deck.type != type) {
            _showConfirmDialog(context, 'デッキタイプの変更', 'デッキタイプを変更すると、現在のカードが削除されます。よろしいですか？', () {
              final updatedDeck = Deck(id: deck.id, name: deck.name, type: type, cardIds: []);
              ref.read(deckCollectionProvider.notifier).updateDeck(updatedDeck);
            });
          }
        },
      ),
      // デッキ名変更ボタン
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _renameDeck(context, ref, deck),
      ),
      // 新規デッキボタン
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          _showConfirmDialog(context, '新規デッキ作成', '新しいデッキを作成しますか？（現在のデッキは自動で保存されます）', () {
            final newDeck = Deck(
              id: 'deck_${DateTime.now().millisecondsSinceEpoch}',
              name: '新しいデッキ',
              type: DeckType.main,
            );
            ref.read(deckCollectionProvider.notifier).addDeck(newDeck);
            ref.read(selectedDeckIdProvider.notifier).state = newDeck.id;
          });
        },
      ),
    ];
  }

  void _renameDeck(BuildContext context, WidgetRef ref, Deck deck) {
    final textController = TextEditingController(text: deck.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('デッキ名の変更'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(labelText: 'デッキ名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                final updatedDeck = Deck(id: deck.id, name: textController.text, type: deck.type, cardIds: deck.cardIds);
                ref.read(deckCollectionProvider.notifier).updateDeck(updatedDeck);
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// --- Deck Content View ---
class _DeckContentView extends ConsumerWidget {
  final Deck deck;
  final List<CardData> allCards;

  const _DeckContentView({required this.deck, required this.allCards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardMap = {for (var card in allCards) card.id: card};
    final cardCounts = <String, int>{};
    for (final cardId in deck.cardIds) {
      cardCounts[cardId] = (cardCounts[cardId] ?? 0) + 1;
    }
    final cardEntries = cardCounts.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('${deck.name} (${deck.cardCount}枚)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: cardEntries.isEmpty
              ? const Center(child: Text('カードがありません'))
              : ListView.builder(
                  itemCount: cardEntries.length,
                  itemBuilder: (context, index) {
                    final entry = cardEntries[index];
                    final card = cardMap[entry.key];
                    if (card == null) return ListTile(title: Text('不明なカード: ${entry.key}'));

                    return ListTile(
                      title: Text(card.name),
                      subtitle: Text(_getCardTypeText(card.type)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('×${entry.value}'),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => ref.read(deckCollectionProvider.notifier).removeCardFromDeck(deck.id, card.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// --- Card Collection View ---
class _CardCollectionView extends ConsumerStatefulWidget {
  final Deck deck;
  final List<CardData> allCards;

  const _CardCollectionView({required this.deck, required this.allCards});

  @override
  ConsumerState<_CardCollectionView> createState() => _CardCollectionViewState();
}

class _CardCollectionViewState extends ConsumerState<_CardCollectionView> {
  CardType? _filterType;
  String? _filterTag;
  String? _searchQuery;

  void _addCardToDeck(CardData card) {
    final deck = widget.deck;
    final currentCount = deck.countCard(card.id);
    final limit = deck.type == DeckType.main ? DeckRules.mainDeckSameCardLimit : DeckRules.extraDeckSameCardLimit;

    if (deck.type == DeckType.extra && !DeckRules.canBeInExtraDeck(card.type)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${card.name}はエクストラデッキに入れられません')));
      return;
    }
    if (currentCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${card.name}は最大${limit}枚までしか入れられません')));
      return;
    }
    if (deck.type == DeckType.extra && deck.cardCount >= DeckRules.extraDeckMaxCards) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エクストラデッキは${DeckRules.extraDeckMaxCards}枚までです')));
      return;
    }

    ref.read(deckCollectionProvider.notifier).addCardToDeck(deck.id, card.id);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCards = widget.allCards.where((card) {
      if (_filterType != null && card.type != _filterType) return false;
      if (_filterTag != null && !card.tags.contains(_filterTag)) return false;
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        if (!card.name.toLowerCase().contains(query) && !card.text.toLowerCase().contains(query)) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'カードを検索', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (value) => setState(() => _searchQuery = value.isEmpty ? null : value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<CardType?>(
                      isExpanded: true,
                      value: _filterType,
                      hint: const Text('タイプを選択'),
                      items: [
                        const DropdownMenuItem<CardType?>(value: null, child: Text('すべて')),
                        ...CardType.values.map((type) => DropdownMenuItem(value: type, child: Text(_getCardTypeText(type)))),
                      ],
                      onChanged: (value) => setState(() => _filterType = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final availableTags = extractUniqueTagsFromCards(widget.allCards);
                        if (availableTags.isEmpty) return;
                        final selectedTag = await showDialog<String?>(
                          context: context,
                          builder: (context) => TagSelectorDialog(availableTags: availableTags, initialSelectedTag: _filterTag),
                        );
                        if (selectedTag != _filterTag) setState(() => _filterTag = selectedTag);
                      },
                      child: Text('タグ: ${_filterTag ?? "すべて"}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredCards.isEmpty
              ? const Center(child: Text('カードがありません'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: filteredCards.length,
                  itemBuilder: (context, index) {
                    final card = filteredCards[index];
                    return InkWell(
                      onTap: () => _addCardToDeck(card),
                      onLongPress: () => showDialog(context: context, builder: (context) => CardDetailDialog(card: card)),
                      child: Material(
                        elevation: 2,
                        child: _CardItem(card: card),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CardItem extends StatelessWidget {
  final CardData card;
  const _CardItem({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: _getCardTypeColor(card.type),
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_getCardTypeText(card.type), style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(card.text, style: const TextStyle(fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (card.stats != null)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text('ATK: ${card.stats!.atk} / DEF: ${card.stats!.def} / HP: ${card.stats!.hp}', style: const TextStyle(fontSize: 10)),
          ),
        if (card.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(card.tags.join(', '), style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}

// Helper methods
Color _getCardTypeColor(CardType type) {
  switch (type) {
    case CardType.monster: return Colors.brown;
    case CardType.spell: return Colors.blue;
    case CardType.ritual: return Colors.purple;
    case CardType.artifact: return Colors.orange;
    case CardType.relic: return Colors.deepOrange;
    case CardType.equip: return Colors.teal;
    case CardType.domain: return Colors.green;
    case CardType.arcane: return Colors.indigo;
  }
}

String _getCardTypeText(CardType type) {
  switch (type) {
    case CardType.monster: return 'モンスター';
    case CardType.spell: return '魔法';
    case CardType.ritual: return '儀式';
    case CardType.artifact: return 'アーティファクト';
    case CardType.relic: return 'レリック';
    case CardType.equip: return '装備';
    case CardType.domain: return 'ドメイン';
    case CardType.arcane: return '秘術';
  }
}
