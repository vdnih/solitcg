import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/deck.dart';
import '../../engine/types.dart';
import '../../services/card_loader.dart';
import '../../providers/deck_provider.dart';
import '../widgets/tag_selector_dialog.dart';
import '../widgets/card_detail_dialog.dart';

class DeckBuilderScreen extends ConsumerStatefulWidget {
  const DeckBuilderScreen({super.key});

  @override
  ConsumerState<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends ConsumerState<DeckBuilderScreen> {
  // 現在編集中のデッキ
  Deck? _currentDeck;
  
  // 全カードリスト
  List<Card> _allCards = [];
  
  // カード表示用フィルター設定
  CardType? _filterType;
  String? _filterTag;
  String? _searchQuery;

  // デッキ検証結果
  DeckValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    _loadCards();
    _loadDecks();
  }

  // カードデータの読み込み
  Future<void> _loadCards() async {
    final cards = await CardLoaderService.loadAllCards();
    setState(() {
      _allCards = cards;
    });
  }

  // デッキの読み込み
  Future<void> _loadDecks() async {
    final collection = await DeckStorage.loadDecks();
    final selectedId = ref.read(selectedDeckIdProvider);

    if (selectedId != null) {
      final deck = collection.getDeck(selectedId);
      if (deck != null) {
        setState(() {
          _currentDeck = deck;
        });
        _validateCurrentDeck();
        return;
      }
    }

    if (selectedId == null) {
      _createNewDeck();
      return;
    }

    if (collection.decks.isNotEmpty) {
      setState(() {
        _currentDeck = collection.decks.first;
      });
      _validateCurrentDeck();
    } else {
      _createNewDeck();
    }
  }

  // 新規デッキの作成
  void _createNewDeck() {
    final newDeck = Deck(
      id: 'deck_${DateTime.now().millisecondsSinceEpoch}',
      name: '新しいデッキ',
      type: DeckType.main,
    );
    setState(() {
      _currentDeck = newDeck;
    });
    ref.read(selectedDeckIdProvider.notifier).state = newDeck.id;
    _validateCurrentDeck();
  }

  // 現在のデッキを検証
  Future<void> _validateCurrentDeck() async {
    if (_currentDeck != null) {
      final result = await DeckValidator.validateDeck(_currentDeck!, _allCards);
      setState(() {
        _validationResult = result;
      });
    }
  }
  
  // タグ選択ダイアログを表示
  Future<void> _showTagSelectorDialog() async {
    if (_allCards.isEmpty) return;
    
    // 利用可能なタグを抽出
    final availableTags = extractUniqueTagsFromCards(_allCards);
    
    if (availableTags.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('利用可能なタグがありません'))
        );
      }
      return;
    }
    
    if (!mounted) return;
    
    // ダイアログを表示
    final selectedTag = await showDialog<String?>(
      context: context,
      builder: (context) => TagSelectorDialog(
        availableTags: availableTags,
        initialSelectedTag: _filterTag,
      ),
    );
    
    // mountedチェックを追加
    if (!mounted) return;
    
    // 選択結果を反映
    if (selectedTag != _filterTag) {
      setState(() {
        _filterTag = selectedTag;
      });
    }
  }
  
  // カード詳細ダイアログを表示
  void _showCardDetail(Card card) {
    showDialog(
      context: context,
      builder: (context) => CardDetailDialog(card: card),
    );
  }

  // デッキにカードを追加
  void _addCardToDeck(Card card) {
    if (_currentDeck == null) return;
    
    // デッキタイプのチェック
    if (_currentDeck!.type == DeckType.extra && !DeckRules.canBeInExtraDeck(card.type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${card.name}はエクストラデッキに入れられません'))
      );
      return;
    }
    
    // 同一カードの制限チェック
    int currentCount = _currentDeck!.countCard(card.id);
    int limit = _currentDeck!.type == DeckType.main 
        ? DeckRules.mainDeckSameCardLimit 
        : DeckRules.extraDeckSameCardLimit;
        
    if (currentCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${card.name}は最大${limit}枚までしか入れられません'))
      );
      return;
    }
    
    // エクストラデッキの枚数制限チェック
    if (_currentDeck!.type == DeckType.extra && 
        _currentDeck!.cardCount >= DeckRules.extraDeckMaxCards) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクストラデッキは${DeckRules.extraDeckMaxCards}枚までです'))
      );
      return;
    }
    
    setState(() {
      _currentDeck!.addCard(card.id);
    });
    _validateCurrentDeck();
  }
  
  // デッキからカードを削除
  void _removeCardFromDeck(String cardId) {
    if (_currentDeck == null) return;
    
    setState(() {
      _currentDeck!.removeCard(cardId);
    });
    _validateCurrentDeck();
  }
  
  // デッキの保存
  Future<void> _saveDeck() async {
    if (_currentDeck == null) return;
    
    // コレクションに現在のデッキを追加して保存
    final collection = await DeckStorage.loadDecks();
    
    // 既存デッキの場合は更新、新規の場合は追加
    int existingIndex = collection.decks.indexWhere((d) => d.id == _currentDeck!.id);
    if (existingIndex >= 0) {
      collection.decks[existingIndex] = _currentDeck!;
    } else {
      collection.addDeck(_currentDeck!);
    }
    
    final success = await DeckStorage.saveDecks(collection);
    
    // mountedチェックを追加
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'デッキを保存しました' : 'デッキの保存に失敗しました'))
      );
    }
  }
  
  // デッキ名の変更
  void _renameDeck() {
    if (_currentDeck == null) return;
    
    final textController = TextEditingController(text: _currentDeck!.name);
    
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                setState(() {
                  _currentDeck!.name = textController.text;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDeck?.name ?? 'デッキビルダー'),
        actions: [
          // デッキタイプ切り替え
          DropdownButton<DeckType>(
            value: _currentDeck?.type ?? DeckType.main,
            items: DeckType.values.map((type) {
              String label = type == DeckType.main ? 'メインデッキ' : 'エクストラデッキ';
              return DropdownMenuItem(
                value: type,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(label),
                ),
              );
            }).toList(),
            onChanged: (type) {
              if (type != null && _currentDeck != null && _currentDeck!.type != type) {
                // デッキタイプ変更時に確認ダイアログを表示
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('デッキタイプの変更'),
                    content: const Text('デッキタイプを変更すると、現在のカードが削除されます。よろしいですか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentDeck!.type = type;
                            _currentDeck!.cardIds = [];
                          });
                          _validateCurrentDeck();
                          Navigator.pop(context);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          
          // デッキ名変更ボタン
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _renameDeck,
          ),
          
          // デッキ保存ボタン
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDeck,
          ),
          
          // 新規デッキボタン
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // 未保存の変更がある場合は確認
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('新規デッキ作成'),
                  content: const Text('現在のデッキの変更が保存されていない場合は失われます。新しいデッキを作成しますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () {
                        _createNewDeck();
                        Navigator.pop(context);
                      },
                      child: const Text('作成'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      
      body: _currentDeck == null 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // デッキ検証結果
              if (_validationResult != null)
                Container(
                  color: _validationResult!.isValid ? Colors.green[100] : Colors.red[100],
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _validationResult!.isValid 
                          ? 'デッキは有効です' 
                          : 'デッキは無効です',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _validationResult!.isValid ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                      if (!_validationResult!.isValid)
                        ...(_validationResult!.errors.map((error) => Text('• $error'))),
                    ],
                  ),
                ),
                
              // デッキとカード一覧を横に並べるレイアウト
              Expanded(
                child: Row(
                  children: [
                    // デッキ内容表示 (左側)
                    Expanded(
                      flex: 2,
                      child: _buildDeckView(),
                    ),
                    
                    // 区切り線
                    const VerticalDivider(thickness: 1, width: 1),
                    
                    // カードコレクション表示 (右側)
                    Expanded(
                      flex: 3,
                      child: _buildCardCollectionView(),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
  
  // デッキ内容表示ウィジェット
  Widget _buildDeckView() {
    if (_currentDeck == null) return const Center(child: Text('デッキが読み込まれていません'));
    
    final deckCards = _currentDeck!.cardIds;
    
    // カードIDからカードオブジェクトを取得するマップを作成
    final cardMap = {for (var card in _allCards) card.id: card};
    
    // カードIDをグループ化して枚数をカウント
    final cardCounts = <String, int>{};
    for (final cardId in deckCards) {
      cardCounts[cardId] = (cardCounts[cardId] ?? 0) + 1;
    }
    
    final cardEntries = cardCounts.entries.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '${_currentDeck!.name} (${_currentDeck!.cardCount}枚)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        
        Expanded(
          child: cardEntries.isEmpty
            ? const Center(child: Text('カードがありません'))
            : ListView.builder(
                itemCount: cardEntries.length,
                itemBuilder: (context, index) {
                  final entry = cardEntries[index];
                  final cardId = entry.key;
                  final count = entry.value;
                  final card = cardMap[cardId];
                  
                  if (card == null) {
                    return ListTile(
                      title: Text('不明なカード: $cardId'),
                      trailing: Text('×$count'),
                    );
                  }
                  
                  return ListTile(
                    title: Text(card.name),
                    subtitle: Text(_getCardTypeText(card.type)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('×$count'),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeCardFromDeck(cardId),
                          color: Colors.red,
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
  
  // カード一覧表示ウィジェット
  Widget _buildCardCollectionView() {
    // フィルター適用
    final filteredCards = _allCards.where((card) {
      // カードタイプでフィルター
      if (_filterType != null && card.type != _filterType) {
        return false;
      }
      
      // タグでフィルター
      if (_filterTag != null && !card.tags.contains(_filterTag)) {
        return false;
      }
      
      // 検索クエリでフィルター
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        if (!card.name.toLowerCase().contains(query) && 
            !card.text.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    return Column(
      children: [
        // 検索・フィルターUI
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // 検索フィールド
              TextField(
                decoration: const InputDecoration(
                  labelText: 'カードを検索',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.isEmpty ? null : value;
                  });
                },
              ),
              
              const SizedBox(height: 8),
              
              // カードタイプとタグのフィルター
              Row(
                children: [
                  // カードタイプフィルター
                  Expanded(
                    child: DropdownButton<CardType?>(
                      isExpanded: true,
                      value: _filterType,
                      hint: const Text('タイプを選択'),
                      items: [
                        const DropdownMenuItem<CardType?>(
                          value: null,
                          child: Text('すべて'),
                        ),
                        ...CardType.values.map((type) => 
                          DropdownMenuItem(
                            value: type,
                            child: Text(_getCardTypeText(type)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterType = value;
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // タグフィルター（実装は省略 - カードからタグを抽出する必要がある）
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showTagSelectorDialog(),
                      child: Text('タグ: ${_filterTag ?? "すべて"}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // カード一覧
        Expanded(
          child: filteredCards.isEmpty
            ? const Center(child: Text('カードがありません'))
            : GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredCards.length,
                itemBuilder: (context, index) {
                  final card = filteredCards[index];
                  return _buildCardItem(card);
                },
              ),
        ),
      ],
    );
  }
  
  // カードアイテム表示
  Widget _buildCardItem(Card card) {
    return InkWell(
      onTap: () => _addCardToDeck(card),
      onLongPress: () => _showCardDetail(card),
      child: Material(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カード名とタイプ
            Container(
              color: _getCardTypeColor(card.type),
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getCardTypeText(card.type),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            // カードテキスト
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  card.text,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            // カードのステータス（モンスターの場合）
            if (card.stats != null)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'ATK: ${card.stats!.atk} / DEF: ${card.stats!.def} / HP: ${card.stats!.hp}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              
            // カードのタグ
            if (card.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  card.tags.join(', '),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // カードタイプに応じた色を取得
  Color _getCardTypeColor(CardType type) {
    switch (type) {
      case CardType.monster:
        return Colors.brown;
      case CardType.spell:
        return Colors.blue;
      case CardType.ritual:
        return Colors.purple;
      case CardType.artifact:
        return Colors.orange;
      case CardType.relic:
        return Colors.deepOrange;
      case CardType.equip:
        return Colors.teal;
      case CardType.domain:
        return Colors.green;
      case CardType.arcane:
        return Colors.indigo;
    }
  }
  
  // カードタイプのテキストを取得
  String _getCardTypeText(CardType type) {
    switch (type) {
      case CardType.monster:
        return 'モンスター';
      case CardType.spell:
        return '魔法';
      case CardType.ritual:
        return '儀式';
      case CardType.artifact:
        return 'アーティファクト';
      case CardType.relic:
        return 'レリック';
      case CardType.equip:
        return '装備';
      case CardType.domain:
        return 'ドメイン';
      case CardType.arcane:
        return '秘術';
    }
  }
}