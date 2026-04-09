// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../domain/models/card_data.dart';
import '../../domain/models/card_instance.dart';
import '../../domain/models/choice_request.dart';
import '../theme/game_theme.dart';

/// カード選択 UI オーバーレイ。
///
/// エンジンが複数の候補カードからプレイヤーの選択を必要とするときに表示される。
/// [request.candidates] を一覧表示し、[request.count] 枚選択して確定ボタンを押すと
/// [onConfirm] がコールされる。
class ChoiceOverlay extends StatefulWidget {
  final ChoiceRequest request;
  final void Function(List<CardInstance> selected) onConfirm;

  const ChoiceOverlay({
    super.key,
    required this.request,
    required this.onConfirm,
  });

  @override
  State<ChoiceOverlay> createState() => _ChoiceOverlayState();
}

class _ChoiceOverlayState extends State<ChoiceOverlay> {
  // 選択済みカードの instanceId を挿入順に管理するリスト
  final List<String> _selectedIds = [];

  void _toggleCard(CardInstance card) {
    setState(() {
      if (_selectedIds.contains(card.instanceId)) {
        _selectedIds.remove(card.instanceId);
      } else {
        if (_selectedIds.length >= widget.request.count) {
          // 上限に達したら最古の選択を解除して新しいカードを選択
          _selectedIds.removeAt(0);
        }
        _selectedIds.add(card.instanceId);
      }
    });
  }

  bool get _isConfirmEnabled => _selectedIds.length == widget.request.count;

  void _handleConfirm() {
    final selected = widget.request.candidates
        .where((c) => _selectedIds.contains(c.instanceId))
        .toList();
    widget.onConfirm(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.75),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // メッセージ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.request.message ?? 'カードを${widget.request.count}枚選んでください',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              // 選択状況
              Text(
                '${_selectedIds.length} / ${widget.request.count} 枚選択中',
                style: TextStyle(
                  color: _isConfirmEnabled
                      ? GameTheme.selectionGlow
                      : const Color(0xFF8B949E),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 候補カード（手札と同じサイズ・横並び）
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final card in widget.request.candidates)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 100,
                          height: 140,
                          child: _CandidateCard(
                            card: card,
                            isSelected: _selectedIds.contains(card.instanceId),
                            onTap: () => _toggleCard(card),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 確定ボタン
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isConfirmEnabled ? _handleConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameTheme.selectionGlow,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFF30363D),
                      disabledForegroundColor: const Color(0xFF8B949E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '確定 (${_selectedIds.length}/${widget.request.count})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final CardInstance card;
  final bool isSelected;
  final VoidCallback onTap;

  const _CandidateCard({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradColors = GameTheme.cardGradient(card.card.type);
    final accentColor = GameTheme.cardAccentColor(card.card.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradColors,
          ),
          border: Border.all(
            color: isSelected
                ? GameTheme.selectionBorder
                : accentColor.withOpacity(0.4),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: GameTheme.selectionGlow.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            // カード画像またはプレースホルダー
            if (card.card.image != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.5),
                  child: Image.asset(
                    'assets/images/cards/${card.card.image}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(gradColors),
                  ),
                ),
              )
            else
              Positioned.fill(child: _buildPlaceholder(gradColors)),
            // カード名（下部）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8.5),
                    bottomRight: Radius.circular(8.5),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
                child: Text(
                  card.card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 選択チェックマーク
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: GameTheme.selectionGlow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(List<Color> gradColors) {
    return Center(
      child: Text(
        _typeIcon(card.card.type),
        style: TextStyle(
          fontSize: 36,
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
