import 'package:flutter/material.dart' hide Card;
import '../../engine/types.dart';

/// カード詳細ダイアログウィジェット
class CardDetailDialog extends StatelessWidget {
  final Card card;
  
  const CardDetailDialog({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8 > 500 ? 500 : MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カードヘッダー（名前とタイプ）
            Container(
              color: _getCardTypeColor(card.type),
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getCardTypeText(card.type),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            // カードタグ
            if (card.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: card.tags.map((tag) => Chip(
                    label: Text(tag),
                    backgroundColor: Colors.grey[200],
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6.0),
                  )).toList(),
                ),
              ),
            
            // カードステータス（モンスターの場合）
            if (card.stats != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatLabel('ATK', card.stats!.atk.toString(), Colors.red),
                    _buildStatLabel('DEF', card.stats!.def.toString(), Colors.blue),
                    _buildStatLabel('HP', card.stats!.hp.toString(), Colors.green),
                  ],
                ),
              ),
            
            // カード説明テキスト
            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                '効果:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              card.text,
              style: const TextStyle(fontSize: 14),
            ),
            
            // カード能力詳細
            if (card.abilities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '能力:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...card.abilities.map((ability) => _buildAbilityInfo(ability)),
                  ],
                ),
              ),
            
            // 閉じるボタン
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ステータスラベルウィジェットを作成
  Widget _buildStatLabel(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // 能力情報ウィジェットを作成
  Widget _buildAbilityInfo(Ability ability) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '発動タイミング: ${_getTriggerWhenText(ability.when)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (ability.pre != null && ability.pre!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '条件: ${ability.pre!.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (ability.effects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '効果: ${ability.effects.map((e) => '${e.op}(${_formatParams(e.params)})').join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // パラメータのフォーマット
  String _formatParams(Map<String, dynamic> params) {
    return params.entries.map((e) => '${e.key}:${e.value}').join(', ');
  }

  // トリガータイミングのテキストを取得
  String _getTriggerWhenText(TriggerWhen when) {
    switch (when) {
      case TriggerWhen.onPlay:
        return 'プレイ時';
      case TriggerWhen.onDestroy:
        return '破壊時';
      case TriggerWhen.static:
        return '常時';
      case TriggerWhen.activated:
        return '起動型';
      case TriggerWhen.onDraw:
        return 'ドロー時';
      case TriggerWhen.onDiscard:
        return '捨て札時';
    }
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