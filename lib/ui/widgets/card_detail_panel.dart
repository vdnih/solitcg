// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../domain/models/card_data.dart';
import '../../domain/models/card_selection_state.dart';
import '../theme/game_theme.dart';

/// カード選択時に画面下部にスライドインするカード詳細パネル。
///
/// 選択されたカードの画像（あれば）・名前・種別・ステータス・効果テキストを表示し、
/// プレイ/発動/閉じるのアクションを提供する。
class CardDetailPanel extends StatelessWidget {
  final CardSelectionState selection;
  final void Function(CardSelectionState) onConfirm;
  final VoidCallback onDismiss;

  const CardDetailPanel({
    super.key,
    required this.selection,
    required this.onConfirm,
    required this.onDismiss,
  });

  bool get _hasActivated => selection.card.card.abilities
      .any((a) => a.when == TriggerWhen.activated);

  bool get _canAct {
    if (selection.zone == SelectionZone.hand) return true;
    if (selection.zone == SelectionZone.board && _hasActivated) return true;
    return false;
  }

  String get _actionLabel {
    if (selection.zone == SelectionZone.hand) return 'プレイ';
    if (selection.zone == SelectionZone.board && _hasActivated) return '発動';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF0161B22),
            border: const Border(
              top: BorderSide(color: Color(0xFF30363D), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardArtwork(card: selection.card.card),
                  const SizedBox(width: 16),
                  Expanded(child: _CardInfo(card: selection.card.card)),
                  const SizedBox(width: 12),
                  _ActionButtons(
                    canAct: _canAct,
                    actionLabel: _actionLabel,
                    onConfirm: () => onConfirm(selection),
                    onDismiss: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardArtwork extends StatelessWidget {
  final CardData card;
  const _CardArtwork({required this.card});

  @override
  Widget build(BuildContext context) {
    final gradColors = GameTheme.cardGradient(card.type);
    return Container(
      width: 80,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradColors,
        ),
        border: Border.all(
          color: GameTheme.cardAccentColor(card.type).withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: card.image != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6.5),
              child: Image.asset(
                'assets/images/cards/${card.image}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(gradColors),
              ),
            )
          : _placeholder(gradColors),
    );
  }

  Widget _placeholder(List<Color> gradColors) {
    return Center(
      child: Text(
        _typeIcon(card.type),
        style: TextStyle(
          fontSize: 32,
          color: gradColors[1].withOpacity(0.7),
        ),
      ),
    );
  }

  String _typeIcon(CardType type) {
    switch (type) {
      case CardType.monster:
        return '⚔';
      case CardType.ritual:
        return '✦';
      case CardType.spell:
        return '✦';
      case CardType.arcane:
        return '✧';
      case CardType.artifact:
        return '⬡';
      case CardType.relic:
        return '◈';
      case CardType.equip:
        return '🛡';
      case CardType.domain:
        return '◉';
    }
  }
}

class _CardInfo extends StatelessWidget {
  final CardData card;
  const _CardInfo({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                card.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: GameTheme.cardAccentColor(card.type).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: GameTheme.cardAccentColor(card.type).withOpacity(0.5),
                ),
              ),
              child: Text(
                GameTheme.cardTypeName(card.type),
                style: TextStyle(
                  color: GameTheme.cardAccentColor(card.type),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (card.stats != null) ...[
          const SizedBox(height: 6),
          _StatsRow(stats: card.stats!),
        ],
        if (card.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            card.text,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (card.abilities.isNotEmpty) ...[
          const SizedBox(height: 6),
          ..._buildAbilityTexts(card),
        ],
      ],
    );
  }

  List<Widget> _buildAbilityTexts(CardData card) {
    return card.abilities.map((ability) {
      final timingLabel = _timingLabel(ability.when);
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '[$timingLabel] ',
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: ability.effects.map((e) => e.op).join(', '),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _timingLabel(TriggerWhen when) {
    switch (when) {
      case TriggerWhen.onPlay:
        return '展開時';
      case TriggerWhen.onDestroy:
        return '破壊時';
      case TriggerWhen.activated:
        return '起動効果';
      case TriggerWhen.onDiscard:
        return '廃棄時';
    }
  }
}

class _StatsRow extends StatelessWidget {
  final Stats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBadge(label: 'ATK', value: stats.atk, color: const Color(0xFFEF4444)),
        const SizedBox(width: 6),
        _StatBadge(label: 'DEF', value: stats.def, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        _StatBadge(label: 'HP', value: stats.hp, color: const Color(0xFF22C55E)),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool canAct;
  final String actionLabel;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _ActionButtons({
    required this.canAct,
    required this.actionLabel,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canAct)
          SizedBox(
            width: 72,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        if (canAct) const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: OutlinedButton(
            onPressed: onDismiss,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFF30363D)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('閉じる'),
          ),
        ),
      ],
    );
  }
}
