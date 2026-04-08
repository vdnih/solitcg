// ignore_for_file: deprecated_member_use
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' as material;

import '../../domain/models/card_data.dart';
import '../../domain/models/card_selection_state.dart';
import '../../ui/theme/game_theme.dart';
import '../game/tcg_game.dart';
import './card_component.dart';

/// ゲームの盤面全体を描画し、UI要素を管理するコンポーネント。
///
/// - カードコンポーネントは instanceId をキーとした Map で差分管理する（毎フレーム再生成しない）。
/// - タップ処理は2タップモデル：1回目で選択+詳細表示、2回目でプレイ/発動。
/// - 空白タップ（子コンポーネントが消費しないタップ）で選択解除。
class BoardComponent extends PositionComponent
    with HasGameRef<TCGGame>, TapCallbacks {
  // カードコンポーネントの差分管理マップ (instanceId → component)
  final Map<String, CardComponent> _handComponentMap = {};
  final Map<String, CardComponent> _fieldComponentMap = {};

  // ログ・トリガーキュー用（テキストは毎フレーム再生成でも軽量）
  final List<Component> _logComponents = [];
  final List<Component> _triggerQueueComponents = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = gameRef.size;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateHand();
    _updateField();
    _updateLog();
    _updateTriggerQueue();
  }

  @override
  void render(material.Canvas canvas) {
    // ─── ボード全体背景 ───────────────────────────────────────
    canvas.drawRect(
      material.Rect.fromLTWH(0, 0, size.x, size.y),
      material.Paint()..color = GameTheme.boardBg,
    );

    // ─── グリッドテクスチャ（微細） ───────────────────────────
    final gridPaint = material.Paint()
      ..color = material.Colors.white.withOpacity(0.020);
    const gridSize = 40.0;
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(
        material.Offset(x, 0),
        material.Offset(x, size.y),
        gridPaint,
      );
    }
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(
        material.Offset(0, y),
        material.Offset(size.x, y),
        gridPaint,
      );
    }

    // ─── ゾーン背景 ───────────────────────────────────────────
    _renderZone(canvas, _handZoneRect(), GameTheme.handZoneBg, '手札');
    _renderZone(canvas, _boardZoneRect(), GameTheme.boardZoneBg, 'フィールド');
    _renderZone(canvas, _domainZoneRect(), GameTheme.domainZoneBg, 'ドメイン');

    // ─── HUD（ライフ・スペルカウンター） ─────────────────────
    _renderHud(canvas);

    // ─── ログパネル ───────────────────────────────────────────
    _renderLogPanel(canvas);

    super.render(canvas);
  }

  // ─── ゾーン矩形の定義 ────────────────────────────────────────

  material.Rect _handZoneRect() =>
      material.Rect.fromLTWH(10, 85, size.x - 20, 170);

  material.Rect _boardZoneRect() =>
      material.Rect.fromLTWH(size.x / 2 - 10, 265, size.x / 2, 160);

  material.Rect _domainZoneRect() =>
      material.Rect.fromLTWH(10, 265, size.x / 2 - 20, 160);

  material.Rect _logPanelRect() =>
      material.Rect.fromLTWH(10, size.y - 215, size.x * 0.6, 205);

  void _renderZone(
    material.Canvas canvas,
    material.Rect rect,
    material.Color bg,
    String label,
  ) {
    final rRect = material.RRect.fromRectAndRadius(
      rect,
      const material.Radius.circular(10),
    );
    canvas.drawRRect(rRect, material.Paint()..color = bg);
    canvas.drawRRect(
      rRect,
      material.Paint()
        ..color = GameTheme.zoneBorder
        ..style = material.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // ゾーンラベル
    final labelPainter = material.TextPainter(
      text: material.TextSpan(
        text: label,
        style: material.TextStyle(
          color: GameTheme.hudDimColor.withOpacity(0.7),
          fontSize: 10,
          fontWeight: material.FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      material.Offset(rect.left + 8, rect.top + 5),
    );
  }

  void _renderHud(material.Canvas canvas) {
    final state = gameRef.gameState;
    const hudY = 8.0;

    // ライフポイントピル（左上）
    _renderPill(
      canvas,
      '♥  ${state.playerLife}',
      const material.Offset(10, 8),
      GameTheme.hudLifeColor,
    );

    // スペルカウンター（ライフの右）
    _renderPill(
      canvas,
      '✦  ${state.spellsCastThisTurn}スペル',
      material.Offset(110, hudY),
      GameTheme.hudSpellColor,
    );

    // デッキ・墓地カウント（右上）
    _renderPill(
      canvas,
      '🂠 ${state.deck.count}',
      material.Offset(size.x - 170, hudY),
      GameTheme.hudDimColor,
    );
    _renderPill(
      canvas,
      '☠ ${state.grave.count}',
      material.Offset(size.x - 95, hudY),
      GameTheme.hudDimColor,
    );
  }

  void _renderPill(
    material.Canvas canvas,
    String text,
    material.Offset pos,
    material.Color color,
  ) {
    final painter = material.TextPainter(
      text: material.TextSpan(
        text: text,
        style: material.TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: material.FontWeight.w600,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    painter.layout();
    final pillRect = material.RRect.fromRectAndRadius(
      material.Rect.fromLTWH(
        pos.dx - 6,
        pos.dy - 3,
        painter.width + 12,
        painter.height + 6,
      ),
      const material.Radius.circular(12),
    );
    canvas.drawRRect(
      pillRect,
      material.Paint()..color = color.withOpacity(0.15),
    );
    canvas.drawRRect(
      pillRect,
      material.Paint()
        ..color = color.withOpacity(0.4)
        ..style = material.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas, pos);
  }

  void _renderLogPanel(material.Canvas canvas) {
    final rect = _logPanelRect();
    // 半透明パネル
    canvas.drawRRect(
      material.RRect.fromRectAndRadius(rect, const material.Radius.circular(8)),
      material.Paint()..color = GameTheme.logPanelBg,
    );
  }

  // ─── 手札の差分更新 ──────────────────────────────────────────

  void _updateHand() {
    final state = gameRef.gameState;
    final currentIds = state.hand.cards.map((c) => c.instanceId).toSet();

    // 手札から消えたカードを削除
    final toRemove = _handComponentMap.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in toRemove) {
      final comp = _handComponentMap.remove(id);
      if (comp != null) remove(comp);
    }

    // 手札のカードを追加・位置更新
    for (int i = 0; i < state.hand.count; i++) {
      final card = state.hand.cards[i];
      final targetPos = Vector2(20 + i * 120.0, 100);

      if (_handComponentMap.containsKey(card.instanceId)) {
        // 位置のみ更新
        _handComponentMap[card.instanceId]!.position = targetPos;
      } else {
        // 新規追加
        final component = CardComponent(
          card: card,
          position: targetPos,
          onTap: () {
            final sel = gameRef.gameState.selectedCard.value;
            if (sel?.card.instanceId == card.instanceId) {
              // 2回目タップ: instanceId から実行時点の正しいインデックスを検索してプレイ
              final currentIndex = gameRef.gameState.hand.cards
                  .indexWhere((c) => c.instanceId == card.instanceId);
              if (currentIndex == -1) return; // 既に手札から消えている
              gameRef.gameState.selectCard(null);
              gameRef.playCardFromHand(currentIndex);
            } else {
              // 1回目タップ: 選択（handIndex も実行時点で解決）
              final currentIndex = gameRef.gameState.hand.cards
                  .indexWhere((c) => c.instanceId == card.instanceId);
              if (currentIndex == -1) return;
              gameRef.gameState.selectCard(CardSelectionState(
                card: card,
                zone: SelectionZone.hand,
                handIndex: currentIndex,
              ));
            }
          },
        );
        _handComponentMap[card.instanceId] = component;
        add(component);
      }
    }
  }

  // ─── フィールドの差分更新 ─────────────────────────────────────

  void _updateField() {
    final state = gameRef.gameState;

    // フィールド上の有効なカード ID セット（ドメイン含む）
    final currentIds = <String>{};
    if (state.hasDomain) {
      currentIds.add(state.currentDomain!.instanceId);
    }
    for (final c in state.board.cards) {
      currentIds.add(c.instanceId);
    }

    // 消えたカードを削除
    final toRemove = _fieldComponentMap.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in toRemove) {
      final comp = _fieldComponentMap.remove(id);
      if (comp != null) remove(comp);
    }

    // ドメインカード
    if (state.hasDomain) {
      final domainCard = state.currentDomain!;
      final targetPos = Vector2(size.x / 2 - 160, 280);
      if (_fieldComponentMap.containsKey(domainCard.instanceId)) {
        _fieldComponentMap[domainCard.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: domainCard,
          position: targetPos,
          isField: true,
          onTap: () {
            // ドメインはタップで詳細のみ表示
            gameRef.gameState.selectCard(CardSelectionState(
              card: domainCard,
              zone: SelectionZone.board,
            ));
          },
        );
        _fieldComponentMap[domainCard.instanceId] = component;
        add(component);
      }
    }

    // ボード上のカード
    for (int i = 0; i < state.board.count; i++) {
      final boardCard = state.board.cards[i];
      final targetPos = Vector2(size.x / 2 + 10 + i * 115.0, 280);
      final hasActivated = boardCard.card.abilities
          .any((a) => a.when == TriggerWhen.activated);

      if (_fieldComponentMap.containsKey(boardCard.instanceId)) {
        _fieldComponentMap[boardCard.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: boardCard,
          position: targetPos,
          isField: true,
          onTap: () {
            final sel = gameRef.gameState.selectedCard.value;
            if (hasActivated && sel?.card.instanceId == boardCard.instanceId) {
              // 2回目タップ: 発動
              gameRef.gameState.selectCard(null);
              gameRef.activateCardOnBoard(boardCard);
            } else {
              // 1回目タップ: 選択（activated がなくても詳細表示）
              gameRef.gameState.selectCard(CardSelectionState(
                card: boardCard,
                zone: SelectionZone.board,
              ));
            }
          },
        );
        _fieldComponentMap[boardCard.instanceId] = component;
        add(component);
      }
    }
  }

  // ─── ログ・トリガーキュー ─────────────────────────────────────

  void _updateLog() {
    removeAll(_logComponents);
    _logComponents.clear();

    final recentLogs = gameRef.gameState.actionLog.reversed
        .take(9)
        .toList()
        .reversed
        .toList();

    for (int i = 0; i < recentLogs.length; i++) {
      final isRecent = i == recentLogs.length - 1;
      final logComponent = TextComponent(
        text: recentLogs[i],
        position: Vector2(18, size.y - 205 + i * 20),
        textRenderer: TextPaint(
          style: material.TextStyle(
            color: isRecent ? GameTheme.logTextRecent : GameTheme.logTextOld,
            fontSize: 11,
          ),
        ),
      );
      _logComponents.add(logComponent);
      add(logComponent);
    }
  }

  void _updateTriggerQueue() {
    removeAll(_triggerQueueComponents);
    _triggerQueueComponents.clear();

    final state = gameRef.gameState;
    final queue = state.triggerQueue.toList();
    if (queue.isEmpty) return;

    final queueTitle = TextComponent(
      text: 'チェーン:',
      position: Vector2(size.x - 180, 50),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.orange,
          fontSize: 13,
          fontWeight: material.FontWeight.bold,
        ),
      ),
    );
    _triggerQueueComponents.add(queueTitle);
    add(queueTitle);

    for (int i = 0; i < queue.length; i++) {
      final trigger = queue[i];
      final component = TextComponent(
        text: '${i + 1}. ${trigger.source.card.name}',
        position: Vector2(size.x - 180, 66 + i * 18),
        textRenderer: TextPaint(
          style: const material.TextStyle(
            color: material.Colors.white70,
            fontSize: 11,
          ),
        ),
      );
      _triggerQueueComponents.add(component);
      add(component);
    }
  }

  // ─── 空白タップで選択解除 ─────────────────────────────────────

  @override
  bool onTapDown(TapDownEvent event) {
    // 子コンポーネントがイベントを消費しなかった場合のみここに来る
    gameRef.gameState.selectCard(null);
    return false; // イベントは消費しない（Flame の伝播処理に従う）
  }
}
