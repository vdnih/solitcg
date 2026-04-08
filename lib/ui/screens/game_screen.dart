import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../domain/models/card_selection_state.dart';
import '../../domain/models/deck.dart';
import '../../presentation/game/tcg_game.dart';
import '../widgets/card_detail_panel.dart';

/// ゲームプレイ画面
///
/// TCGGame インスタンスを initState で生成して保持し、
/// selectedCard ValueNotifier を購読してカード詳細パネルを表示する。
class GameScreen extends StatefulWidget {
  final Deck? deck;

  const GameScreen({super.key, this.deck});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TCGGame _game;

  @override
  void initState() {
    super.initState();
    _game = TCGGame(initialDeck: widget.deck);
  }

  void _handleConfirm(CardSelectionState sel) {
    _game.gameState.selectCard(null);
    if (sel.zone == SelectionZone.hand && sel.handIndex != null) {
      _game.playCardFromHand(sel.handIndex!);
    } else if (sel.zone == SelectionZone.board) {
      _game.activateCardOnBoard(sel.card);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD700),
              ),
            ),
            errorBuilder: (context, error) => Center(
              child: Text(
                'エラーが発生しました: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            overlayBuilderMap: {
              'pause': (context, TCGGame game) => Center(
                child: Container(
                  color: Colors.black54,
                  child: const Text(
                    '一時停止中',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
            },
          ),
          // カード詳細パネル（選択時にスライドイン）
          ValueListenableBuilder<CardSelectionState?>(
            valueListenable: _game.gameState.selectedCard,
            builder: (context, selection, _) {
              return AnimatedSlide(
                offset: selection != null ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: selection != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: selection != null
                      ? CardDetailPanel(
                          selection: selection,
                          onConfirm: _handleConfirm,
                          onDismiss: () => _game.gameState.selectCard(null),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
