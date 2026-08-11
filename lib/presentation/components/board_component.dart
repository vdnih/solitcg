import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' as material;

import '../../ui/theme/game_theme.dart';
import '../game/tcg_game.dart';
import './board_layout.dart';
import './board_scroll_controller.dart';
import './card_component.dart';

/// ゲームの盤面全体を描画し、UI要素を管理するコンポーネント。
///
/// レイアウト（上から下、点対称デザイン）:
///   [相手] HUD → 手札（裏向き） → フィールド（ドメイン右・ボード左）
///   ────────── セパレーター ──────────
///   [自分] フィールド（ドメイン左・ボード右） → 手札 → HUD
///
/// レイアウト定数は [BoardLayout]、スクロール状態は [BoardScrollController] に
/// 切り出している。カードタップ時の選択/プレイ判定は `TCGGame` に委譲する
/// （Flame コンポーネントにゲームロジックを持たせない方針のため）。
class BoardComponent extends PositionComponent
    with HasGameReference<TCGGame>, TapCallbacks, DragCallbacks {
  final BoardScrollController _scroll = BoardScrollController();

  // ─── コンポーネント管理 ───────────────────────────────────────

  // 手札カード（_handClipComponent配下、横スクロール）
  final Map<String, CardComponent> _handComponentMap = {};

  // ドメインカード（BoardComponent直下）
  final Map<String, CardComponent> _domainComponentMap = {};

  // ボードカード（_boardClipComponent配下、横スクロール）
  final Map<String, CardComponent> _boardCardComponentMap = {};

  // ボードスクロール用 ClipComponent
  late ClipComponent _boardClipComponent;
  bool _dragIsInBoardZone = false;

  // 手札スクロール用 ClipComponent
  late ClipComponent _handClipComponent;
  bool _dragIsInHandZone = false;

  // トリガーキュー（毎フレーム再生成）
  final List<Component> _triggerQueueComponents = [];

  bool get opponentAreaVisible => _scroll.opponentAreaVisible;
  set opponentAreaVisible(bool value) => _scroll.setOpponentAreaVisible(value, size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;

    // 縦スクロール初期位置: 画面が小さい場合はプレイヤーHUDが見える位置から開始
    _scroll.initViewScrollY(size);

    // 自分フィールドのボードエリアをクリップする（横スクロール用）
    _boardClipComponent = ClipComponent.rectangle(
      position: Vector2(BoardLayout.plyBoardX, BoardLayout.plyFieldY + _scroll.effectiveScrollY),
      size: Vector2(BoardLayout.plyBoardZoneWidth(size), BoardLayout.fieldH),
    );
    add(_boardClipComponent);

    // 自分手札エリアをクリップする（横スクロール用）
    _handClipComponent = ClipComponent.rectangle(
      position: Vector2(10, BoardLayout.plyHandZoneY + _scroll.effectiveScrollY),
      size: Vector2(size.x - 20, BoardLayout.plyHandZoneH),
    );
    add(_handClipComponent);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    // ClipComponent のサイズを新しい画面幅に合わせて更新
    _boardClipComponent.size = Vector2(BoardLayout.plyBoardZoneWidth(size), BoardLayout.fieldH);
    _handClipComponent.size = Vector2(size.x - 20, BoardLayout.plyHandZoneH);
    // スクロール範囲を再クランプ
    _scroll.clampViewScrollY(size);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // ClipComponent の縦位置を毎フレーム同期
    _boardClipComponent.position =
        Vector2(BoardLayout.plyBoardX, BoardLayout.plyFieldY + _scroll.effectiveScrollY);
    _handClipComponent.position =
        Vector2(10, BoardLayout.plyHandZoneY + _scroll.effectiveScrollY);
    _updateHand();
    _updateField();
    _updateTriggerQueue();
  }

  @override
  void render(material.Canvas canvas) {
    // ─── ボード全体背景 ───────────────────────────────────────
    canvas.drawRect(
      material.Rect.fromLTWH(0, 0, size.x, size.y),
      material.Paint()..color = GameTheme.boardBg,
    );

    // ─── グリッドテクスチャ ───────────────────────────────────
    final gridPaint = material.Paint()
      ..color = material.Colors.white.withValues(alpha: 0.018);
    const gridSize = 40.0;
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(
          material.Offset(x, 0), material.Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(
          material.Offset(0, y), material.Offset(size.x, y), gridPaint);
    }

    // ─── 相手HUD（ライフ等）は常に表示 ─────────────────────────
    _renderOpponentHud(canvas);

    // ─── 相手の手札・フィールドゾーン（トグルで非表示可） ────
    if (_scroll.opponentAreaVisible) {
      _renderOpponentHandAndField(canvas);
    }

    // ─── セパレーター ─────────────────────────────────────────
    canvas.drawLine(
      material.Offset(0, BoardLayout.separatorY + _scroll.effectiveScrollY),
      material.Offset(size.x, BoardLayout.separatorY + _scroll.effectiveScrollY),
      material.Paint()
        ..color = GameTheme.zoneBorder.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    // ─── 自分フィールドゾーン ─────────────────────────────────
    _renderZone(
      canvas,
      material.Rect.fromLTWH(BoardLayout.plyDomainX, BoardLayout.plyFieldY + _scroll.effectiveScrollY,
          BoardLayout.domainW, BoardLayout.fieldH),
      GameTheme.domainZoneBg,
      'ドメイン',
    );
    _renderZone(
      canvas,
      material.Rect.fromLTWH(BoardLayout.plyBoardX, BoardLayout.plyFieldY + _scroll.effectiveScrollY,
          BoardLayout.plyBoardZoneWidth(size), BoardLayout.fieldH),
      GameTheme.boardZoneBg,
      'フィールド',
    );

    // ─── 自分手札ゾーン ───────────────────────────────────────
    _renderZone(
      canvas,
      material.Rect.fromLTWH(10, BoardLayout.plyHandZoneY + _scroll.effectiveScrollY, size.x - 20,
          BoardLayout.plyHandZoneH),
      GameTheme.handZoneBg,
      '手札',
    );

    // ─── 自分 HUD ─────────────────────────────────────────────
    _renderPlayerHud(canvas);

    super.render(canvas); // 子コンポーネント（カード・ClipComponent）の描画
  }

  // ─── 相手エリア ───────────────────────────────────────────────

  /// 相手HUD（ライフ・手札枚数等）は常に表示
  void _renderOpponentHud(material.Canvas canvas) {
    final state = game.gameState;
    final s = _scroll.viewScrollY; // HUDはユーザースクロールのみ追従（トグルオフセット不要）
    _renderPill(canvas, '♥ ${state.opponentLife}',
        material.Offset(10, BoardLayout.oppHudY + s), GameTheme.hudLifeColor);
    _renderPill(canvas, '🂠 ${state.opponentHandCount}',
        material.Offset(110, BoardLayout.oppHudY + s), GameTheme.hudDimColor);
    _renderPill(canvas, '📦 40',
        material.Offset(180, BoardLayout.oppHudY + s), GameTheme.hudDimColor);
    _renderPill(canvas, '☠ 0',
        material.Offset(235, BoardLayout.oppHudY + s), GameTheme.hudDimColor);
  }

  /// 相手の手札・フィールドゾーン（トグルで非表示可）
  void _renderOpponentHandAndField(material.Canvas canvas) {
    final state = game.gameState;
    final s = _scroll.effectiveScrollY;

    // 相手手札ゾーン（裏向きカード）
    _renderZone(
      canvas,
      material.Rect.fromLTWH(10, BoardLayout.oppHandZoneY + s, size.x - 20, BoardLayout.oppHandZoneH),
      GameTheme.handZoneBg,
      '相手の手札',
    );
    _renderOpponentHandCards(canvas, state.opponentHandCount);

    // 相手フィールド：ボード（左）・ドメイン（右）— 点対称
    _renderZone(
      canvas,
      material.Rect.fromLTWH(BoardLayout.oppBoardX, BoardLayout.oppFieldY + s,
          BoardLayout.oppBoardZoneWidth(size), BoardLayout.fieldH),
      GameTheme.boardZoneBg,
      '相手のフィールド',
    );
    _renderZone(
      canvas,
      material.Rect.fromLTWH(BoardLayout.oppDomainX(size), BoardLayout.oppFieldY + s,
          BoardLayout.domainW, BoardLayout.fieldH),
      GameTheme.domainZoneBg,
      '相手のドメイン',
    );
  }

  void _renderOpponentHandCards(material.Canvas canvas, int count) {
    final displayCount = min(count, 7);
    // 右から左に並べる（点対称: 自分の手札は左から右）
    final cardY =
        BoardLayout.oppHandZoneY + (BoardLayout.oppHandZoneH - BoardLayout.cardH) / 2 + _scroll.effectiveScrollY;
    for (int i = 0; i < displayCount; i++) {
      final cardX = size.x - 15 - BoardLayout.cardW - i * BoardLayout.opponentCardPitch;
      if (cardX < 15) break;
      _renderFaceDownCard(
        canvas,
        material.Rect.fromLTWH(cardX, cardY, BoardLayout.cardW, BoardLayout.cardH),
      );
    }
  }

  void _renderFaceDownCard(material.Canvas canvas, material.Rect rect) {
    final rRect = material.RRect.fromRectAndRadius(
        rect, const material.Radius.circular(8));
    // 裏面背景
    canvas.drawRRect(
        rRect, material.Paint()..color = const material.Color(0xFF1A2545));
    // 縦ストライプ模様（カード裏面らしさ）
    final stripePaint = material.Paint()
      ..color = const material.Color(0xFF223366)
      ..strokeWidth = 4;
    canvas.save();
    canvas.clipRRect(rRect);
    for (double x = rect.left; x < rect.right; x += 10) {
      canvas.drawLine(
          material.Offset(x, rect.top), material.Offset(x, rect.bottom), stripePaint);
    }
    canvas.restore();
    // ボーダー
    canvas.drawRRect(
      rRect,
      material.Paint()
        ..color = const material.Color(0xFF3A5580)
        ..style = material.PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ─── HUD ─────────────────────────────────────────────────────

  void _renderPlayerHud(material.Canvas canvas) {
    final state = game.gameState;
    final hudY = BoardLayout.plyHudY + _scroll.effectiveScrollY;

    _renderPill(canvas, '♥ ${state.playerLife}',
        material.Offset(10, hudY), GameTheme.hudLifeColor);
    _renderPill(canvas, '🂠 ${state.deck.count}',
        material.Offset(size.x - 170, hudY), GameTheme.hudDimColor);
    _renderPill(canvas, '☠ ${state.grave.count}',
        material.Offset(size.x - 95, hudY), GameTheme.hudDimColor);
  }

  // ─── ゾーン描画ヘルパー ───────────────────────────────────────

  void _renderZone(
    material.Canvas canvas,
    material.Rect rect,
    material.Color bg,
    String label,
  ) {
    final rRect = material.RRect.fromRectAndRadius(
        rect, const material.Radius.circular(10));
    canvas.drawRRect(rRect, material.Paint()..color = bg);
    canvas.drawRRect(
      rRect,
      material.Paint()
        ..color = GameTheme.zoneBorder
        ..style = material.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final labelPainter = material.TextPainter(
      text: material.TextSpan(
        text: label,
        style: material.TextStyle(
          color: GameTheme.hudDimColor.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: material.FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(canvas, material.Offset(rect.left + 8, rect.top + 5));
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
            color: color, fontSize: 11, fontWeight: material.FontWeight.w600),
      ),
      textDirection: material.TextDirection.ltr,
    );
    painter.layout();
    final pillRect = material.RRect.fromRectAndRadius(
      material.Rect.fromLTWH(
          pos.dx - 6, pos.dy - 3, painter.width + 12, painter.height + 6),
      const material.Radius.circular(12),
    );
    canvas.drawRRect(pillRect, material.Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawRRect(
      pillRect,
      material.Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = material.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas, pos);
  }

  // ─── 手札の差分更新 ──────────────────────────────────────────

  void _updateHand() {
    final state = game.gameState;
    final currentIds = state.hand.cards.map((c) => c.instanceId).toSet();

    // 消えたカードを削除
    for (final id in _handComponentMap.keys
        .where((id) => !currentIds.contains(id))
        .toList()) {
      final comp = _handComponentMap.remove(id);
      if (comp != null) _handClipComponent.remove(comp);
    }

    // 手札横スクロールのクランプ
    if (state.hand.count > 0) {
      final totalW = 15 + state.hand.count * BoardLayout.cardPitch - 12.0;
      final handZoneW = size.x - 20;
      _scroll.handScrollX = BoardScrollController.clampHorizontalOverflow(
          _scroll.handScrollX, totalW, handZoneW);
    } else {
      _scroll.handScrollX = 0.0;
    }

    // 手札カードを追加・位置更新（ClipComponent内ローカル座標）
    final cardY = (BoardLayout.plyHandZoneH - BoardLayout.cardH) / 2; // clip 内中央
    for (int i = 0; i < state.hand.count; i++) {
      final card = state.hand.cards[i];
      final targetPos = Vector2(_scroll.handScrollX + 15 + i * BoardLayout.cardPitch, cardY);

      if (_handComponentMap.containsKey(card.instanceId)) {
        _handComponentMap[card.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: card,
          position: targetPos,
          onTap: () => game.onHandCardTapped(card),
        );
        _handComponentMap[card.instanceId] = component;
        _handClipComponent.add(component);
      }
    }
  }

  // ─── フィールドの差分更新 ─────────────────────────────────────

  void _updateField() {
    final state = game.gameState;

    // ── ドメインカード（BoardComponent直下） ──────────────────
    final domainId =
        state.hasDomain ? state.currentDomain!.instanceId : null;

    for (final id in _domainComponentMap.keys
        .where((id) => id != domainId)
        .toList()) {
      final comp = _domainComponentMap.remove(id);
      if (comp != null) remove(comp);
    }

    if (state.hasDomain) {
      final domainCard = state.currentDomain!;
      // ドメインスロット(plyDomainX, plyFieldY, domainW, fieldH)内に中央配置
      final targetPos = Vector2(
        BoardLayout.plyDomainX + (BoardLayout.domainW - BoardLayout.cardW) / 2,
        BoardLayout.plyFieldY + (BoardLayout.fieldH - BoardLayout.cardH) / 2 + _scroll.effectiveScrollY,
      );
      if (_domainComponentMap.containsKey(domainCard.instanceId)) {
        _domainComponentMap[domainCard.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: domainCard,
          position: targetPos,
          isField: true,
          onTap: () => game.onDomainCardTapped(domainCard),
        );
        _domainComponentMap[domainCard.instanceId] = component;
        add(component);
      }
    }

    // ── ボードカード（_boardClipComponent配下、横スクロール） ──
    final currentBoardIds =
        state.board.cards.map((c) => c.instanceId).toSet();

    for (final id in _boardCardComponentMap.keys
        .where((id) => !currentBoardIds.contains(id))
        .toList()) {
      final comp = _boardCardComponentMap.remove(id);
      if (comp != null) _boardClipComponent.remove(comp);
    }

    // スクロールオフセットのクランプ
    // totalW がゾーン幅を超えた分だけ左スクロール可能（minScroll は常に <= 0）
    if (state.board.count > 0) {
      final totalW = state.board.count * BoardLayout.cardPitch - 12.0;
      _scroll.boardScrollX = BoardScrollController.clampHorizontalOverflow(
          _scroll.boardScrollX, totalW, BoardLayout.plyBoardZoneWidth(size));
    } else {
      _scroll.boardScrollX = 0.0;
    }

    // ボードカード追加/位置更新（ClipComponent内ローカル座標）
    final cardY = (BoardLayout.fieldH - BoardLayout.cardH) / 2; // ClipComponent内で縦中央
    for (int i = 0; i < state.board.count; i++) {
      final boardCard = state.board.cards[i];
      final targetPos = Vector2(_scroll.boardScrollX + i * BoardLayout.cardPitch, cardY);

      if (_boardCardComponentMap.containsKey(boardCard.instanceId)) {
        _boardCardComponentMap[boardCard.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: boardCard,
          position: targetPos,
          isField: true,
          onTap: () => game.onBoardCardTapped(boardCard),
        );
        _boardCardComponentMap[boardCard.instanceId] = component;
        _boardClipComponent.add(component);
      }
    }
  }

  // ─── トリガーキュー ───────────────────────────────────────────

  void _updateTriggerQueue() {
    removeAll(_triggerQueueComponents);
    _triggerQueueComponents.clear();

    final queue = game.gameState.triggerQueue.toList();
    if (queue.isEmpty) return;

    final queueTitle = TextComponent(
      text: 'キュー:',
      position: Vector2(size.x - 180, BoardLayout.separatorY + _scroll.effectiveScrollY + 10),
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
        position: Vector2(size.x - 180, BoardLayout.separatorY + _scroll.effectiveScrollY + 26 + i * 18),
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

  // ─── ドラッグ（縦スクロール・手札横スクロール・ボード横スクロール） ─

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final pos = event.localPosition;
    // スクロール補正後のY座標でヒットテスト
    final adjustedY = pos.y - _scroll.effectiveScrollY;
    final boardRect = BoardLayout.boardRect(size);
    final handRect = BoardLayout.handRect(size);
    _dragIsInBoardZone =
        boardRect.contains(material.Offset(pos.x, adjustedY));
    _dragIsInHandZone =
        handRect.contains(material.Offset(pos.x, adjustedY));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragIsInBoardZone) {
      _scroll.boardScrollX += event.localDelta.x;
    } else if (_dragIsInHandZone) {
      _scroll.handScrollX += event.localDelta.x;
    } else {
      // 縦スクロール
      _scroll.viewScrollY += event.localDelta.y;
      _scroll.clampViewScrollY(size);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragIsInBoardZone = false;
    _dragIsInHandZone = false;
  }

  // ─── マウスホイール（Flutter Listener から呼び出し） ─────────

  /// [dx] 水平デルタ, [dy] 垂直デルタ, [localPos] カーソル位置
  void applyMouseScroll(double dx, double dy, material.Offset localPos) {
    // 垂直スクロールは常に縦移動に適用
    if (dy != 0) {
      _scroll.viewScrollY -= dy;
      _scroll.clampViewScrollY(size);
    }
    // 水平スクロールはカーソル下のゾーンに適用
    if (dx != 0) {
      final adjustedY = localPos.dy - _scroll.effectiveScrollY;
      final boardRect = BoardLayout.boardRect(size);
      final handRect = BoardLayout.handRect(size);
      if (boardRect.contains(material.Offset(localPos.dx, adjustedY))) {
        _scroll.boardScrollX -= dx;
      } else if (handRect.contains(material.Offset(localPos.dx, adjustedY))) {
        _scroll.handScrollX -= dx;
      }
    }
  }

  // ─── 空白タップで選択解除 ─────────────────────────────────────

  @override
  bool onTapDown(TapDownEvent event) {
    game.gameState.selectCard(null);
    return false;
  }
}
