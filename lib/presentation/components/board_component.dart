// ignore_for_file: deprecated_member_use

import 'package:flame/components.dart';
import 'package:flutter/material.dart' as material;

import '../game/tcg_game.dart';
import './card_component.dart';

/// ゲームの盤面全体を描画し、UI要素を管理するコンポーネント。
///
/// このコンポーネントは、手札、フィールド、デッキ、ログなど、
/// ゲームの視覚的な要素をすべて子コンポーネントとして保持・管理します。
/// `GameState` の変更を検知し、UIをリアクティブに更新する責務を持ちます。
class BoardComponent extends PositionComponent with HasGameRef<TCGGame> {
  /// UI要素を管理するためのリスト
  final List<Component> _handComponents = [];
  final List<Component> _fieldComponents = [];
  final List<Component> _logComponents = [];
  final List<Component> _triggerQueueComponents = [];

  /// UIテキストコンポーネント
  late final TextComponent _instructionComponent;
  late final TextComponent _gameStatusComponent;
  late final TextComponent _lifeComponent;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // ボードコンポーネントのサイズをゲーム画面全体に広げる
    size = gameRef.size;

    // 初期UIのセットアップ
    _setupUI();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 毎フレームUIの状態を最新に保つ
    // 将来的には、GameStateの変更を通知するイベントベースの仕組みに移行すべき
    _updateDisplay();
  }

  @override
  void render(material.Canvas canvas) {
    // 背景色を描画
    canvas.drawRect(
      material.Rect.fromLTWH(0, 0, size.x, size.y),
      material.Paint()..color = material.Colors.black87,
    );
    super.render(canvas);
  }

  /// ゲーム画面の基本的なUI要素（テキストなど）を初期化します。
  void _setupUI() {
    _instructionComponent = TextComponent(
      text: 'Tap cards in your hand to play them',
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 16,
        ),
      ),
    );
    add(_instructionComponent);

    _gameStatusComponent = TextComponent(
      text: '', // updateで更新
      position: Vector2(20, 50),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.yellow,
          fontSize: 14,
        ),
      ),
    );
    add(_gameStatusComponent);

    _lifeComponent = TextComponent(
      text: '', // updateで更新
      position: Vector2(size.x / 2 - 100, 20),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.green,
          fontSize: 18,
          fontWeight: material.FontWeight.bold,
        ),
      ),
    );
    add(_lifeComponent);
  }

  /// ゲームの状態に基づいてUI全体の表示を更新します。
  void _updateDisplay() {
    // 各UIセクションを更新
    _updateHand();
    _updateField();
    _updateLog();
    _updateTriggerQueue();

    // ステータステキストを更新
    _gameStatusComponent.text = _getGameStatusText();
    _lifeComponent.text =
        'Player Life: ${gameRef.gameState.playerLife} | Opponent Life: ${gameRef.gameState.opponentLife}';

    // 勝利条件のチェック
    if (gameRef.gameState.gameWon) {
      // TODO: 勝利画面コンポーネントの表示
    }
  }

  /// ゲームの状態を示すステータステキストを生成します。
  String _getGameStatusText() {
    final state = gameRef.gameState;
    return 'Hand: ${state.hand.count} | Deck: ${state.deck.count} | Grave: ${state.grave.count} | Life: ${state.playerLife} | Spells: ${state.spellsCastThisTurn}';
  }

  /// 手札の表示を更新します。
  void _updateHand() {
    // 既存のコンポーネントをクリア
    removeAll(_handComponents);
    _handComponents.clear();

    final state = gameRef.gameState;
    for (int i = 0; i < state.hand.count; i++) {
      final card = state.hand.cards[i];
      final component = CardComponent(
        card: card,
        position: Vector2(20 + i * 120, 100),
        onTap: () => gameRef.playCardFromHand(i),
      );
      _handComponents.add(component);
      add(component);
    }
  }

  /// フィールド（盤面）の表示を更新します。
  void _updateField() {
    removeAll(_fieldComponents);
    _fieldComponents.clear();

    final state = gameRef.gameState;

    // ドメインカードの表示
    if (state.hasDomain) {
      final domainCard = state.currentDomain!;
      final component = CardComponent(
        card: domainCard,
        position: Vector2(size.x / 2 - 150, 250),
        onTap: null, // ドメインはタップ不可
        isField: true,
      );
      _fieldComponents.add(component);
      add(component);
    }

    // ボード上のカードの表示
    for (int i = 0; i < state.board.count; i++) {
      final boardCard = state.board.cards[i];
      final component = CardComponent(
        card: boardCard,
        position: Vector2(size.x / 2 - 50 + i * 70, 350),
        onTap: () => gameRef.activateCardOnBoard(boardCard),
        isField: true,
      );
      _fieldComponents.add(component);
      add(component);
    }
  }

  /// アクションログの表示を更新します。
  void _updateLog() {
    removeAll(_logComponents);
    _logComponents.clear();

    // 最新10件のログを表示
    final recentLogs = gameRef.gameState.actionLog.reversed
        .take(10)
        .toList()
        .reversed
        .toList();
    for (int i = 0; i < recentLogs.length; i++) {
      final logComponent = TextComponent(
        text: recentLogs[i],
        position: Vector2(20, size.y - 200 + i * 18),
        textRenderer: TextPaint(
          style: const material.TextStyle(
            color: material.Colors.white,
            fontSize: 12,
          ),
        ),
      );
      _logComponents.add(logComponent);
      add(logComponent);
    }
  }

  /// トリガーキューの表示を更新します。
  void _updateTriggerQueue() {
    removeAll(_triggerQueueComponents);
    _triggerQueueComponents.clear();

    final state = gameRef.gameState;

    final queueTitle = TextComponent(
      text: 'Trigger Queue:',
      position: Vector2(size.x - 220, 50),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.orange,
          fontSize: 14,
          fontWeight: material.FontWeight.bold,
        ),
      ),
    );
    _triggerQueueComponents.add(queueTitle);
    add(queueTitle);

    final queue = state.triggerQueue.toList();
    for (int i = 0; i < queue.length; i++) {
      final trigger = queue[i];
      final text = '${i + 1}: ${trigger.source.card.name}';
      final component = TextComponent(
        text: text,
        position: Vector2(size.x - 220, 70 + i * 18),
        textRenderer: TextPaint(
          style: const material.TextStyle(
            color: material.Colors.white,
            fontSize: 12,
          ),
        ),
      );
      _triggerQueueComponents.add(component);
      add(component);
    }
  }
}
