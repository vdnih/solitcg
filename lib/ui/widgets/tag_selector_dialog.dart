import 'package:flutter/material.dart';
import '../../domain/models/card_data.dart';

/// タグ選択ダイアログウィジェット
class TagSelectorDialog extends StatefulWidget {
  final List<String> availableTags;
  final String? initialSelectedTag;

  const TagSelectorDialog({
    Key? key,
    required this.availableTags,
    this.initialSelectedTag,
  }) : super(key: key);

  @override
  State<TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<TagSelectorDialog> {
  String? _selectedTag;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialSelectedTag;
  }

  @override
  Widget build(BuildContext context) {
    // 検索クエリでフィルターしたタグリスト
    final filteredTags = _searchQuery.isEmpty
        ? widget.availableTags
        : widget.availableTags
            .where((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    
    return AlertDialog(
      title: const Text('タグを選択'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 検索フィールド
            TextField(
              decoration: const InputDecoration(
                labelText: 'タグを検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // すべてのタグをクリアするオプション
            ListTile(
              title: const Text('すべて表示（タグなし）'),
              leading: Radio<String?>(
                value: null,
                groupValue: _selectedTag,
                onChanged: (value) {
                  setState(() {
                    _selectedTag = value;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  _selectedTag = null;
                });
              },
            ),
            
            const Divider(),
            
            // タグリスト
            Expanded(
              child: ListView.builder(
                itemCount: filteredTags.length,
                itemBuilder: (context, index) {
                  final tag = filteredTags[index];
                  return ListTile(
                    title: Text(tag),
                    leading: Radio<String?>(
                      value: tag,
                      groupValue: _selectedTag,
                      onChanged: (value) {
                        setState(() {
                          _selectedTag = value;
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        _selectedTag = tag;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedTag),
          child: const Text('選択'),
        ),
      ],
    );
  }
}

/// カードリストからユニークなタグを抽出する
List<String> extractUniqueTagsFromCards(List<CardData> cards) {
  final tagSet = <String>{};
  
  for (final card in cards) {
    for (final tag in card.tags) {
      tagSet.add(tag);
    }
  }
  
  final uniqueTags = tagSet.toList()..sort();
  return uniqueTags;
}