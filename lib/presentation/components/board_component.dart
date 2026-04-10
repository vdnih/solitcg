// ignore_for_file: deprecated_member_use
import 'dart:math';

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
/// レイアウト（上から下、点対称デザイン）:
///   [相手] HUD → 手札（裏向き） → フィールド（ドメイン右・ボード左）
///   ────────── セパレーター ──────────
///   [自分] フィールド（ドメイン左・ボード右） → 手札 → HUD
class BoardComponent extends PositionComponent
    with HasGameRef<TCGGame>, TapCallbacks, DragCallbacks {
  // ─── レイアウト定数 ───────────────────────────────────────────

  // 相手エリア（上）
  static const double _oppHudY = 5.0;
  static const double _oppHandZoneY = 30.0;
  static const double _oppHandZoneH = 155.0;
  static const double _oppFieldY = 190.0;
  static const double _fieldH = 165.0;

  // セパレーター
  static const double _separatorY = 360.0;

  // 自分エリア（下）
  static const double _plyFieldY = 366.0;
  static const double _plyHandZoneY = 536.0;
  static const double _plyHandZoneH = 155.0;
  static const double _plyHudY = 695.0;

  // カードサイズ
  static const double _cardW = 100.0;
  static const double _cardH = 140.0;

  // ドメインゾーン幅
  static const double _domainW = 120.0;

  // 自分: ドメイン左・ボード右
  static const double _plyDomainX = 10.0;
  static const double _plyBoardX = 140.0;

  // 相手: ドメイン右・ボード左（点対称）
  // _oppDomainX = size.x - 10 - _domainW (動的)
  static const double _oppBoardX = 10.0;

  // ─── コンポーネント管理 ───────────────────────────────────────

  // 手札カード（_handClipComponent配下、横スクロール）
  final Map<String, CardComponent> _handComponentMap = {};

  // ドメインカード（BoardComponent直下）
  final Map<String, CardComponent> _domainComponentMap = {};

  // ボードカード（_boardClipComponent配下、横スクロール）
  final Map<String, CardComponent> _boardCardComponentMap = {};

  // ボードスクロール用 ClipComponent
  late ClipComponent _boardClipComponent;
  double _boardScrollX = 0.0;
  bool _dragIsInBoardZone = false;

  // 手札スクロール用 ClipComponent
  late ClipComponent _handClipComponent;
  double _handScrollX = 0.0;
  bool _dragIsInHandZone = false;

  // 縦スクロール
  double _viewScrollY = 0.0;
  static const double _totalContentH = 725.0;
  // 相手エリアの高さ（非表示時にビューをシフトする量）
  static const double _opponentAreaH = _separatorY; // 360.0

  // トリガーキュー（毎フレーム再生成）
  final List<Component> _triggerQueueComponents = [];

  // 相手エリア表示フラグ（外部から setter で制御）
  bool _opponentAreaVisible = true;
  bool get opponentAreaVisible => _opponentAreaVisible;
  set opponentAreaVisible(bool value) {
    if (_opponentAreaVisible == value) return;
    _opponentAreaVisible = value;
    // 非表示にしたら相手エリア分だけ上にシフト、表示に戻したら元に戻す
    _viewScrollY += value ? _opponentAreaH : -_opponentAreaH;
    _clampViewScrollY();
  }

  void _clampViewScrollY() {
    final effectiveH = _opponentAreaVisible
        ? _totalContentH
        : _totalContentH - _opponentAreaH;
    final minScrollY = (size.y - effectiveH).clamp(-double.infinity, 0.0);
    _viewScrollY = _viewScrollY.clamp(minScrollY, 0.0);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = gameRef.size;

    // 縦スクロール初期位置: 画面が小さい場合はプレイヤーHUDが見える位置から開始
    _viewScrollY = (size.y - _totalContentH).clamp(-double.infinity, 0.0);
    _clampViewScrollY();

    // 自分フィールドのボードエリアをクリップする（横スクロール用）
    _boardClipComponent = ClipComponent.rectangle(
      position: Vector2(_plyBoardX, _plyFieldY + _viewScrollY),
      size: Vector2(_plyBoardZoneWidth, _fieldH),
    );
    add(_boardClipComponent);

    // 自分手札エリアをクリップする（横スクロール用）
    _handClipComponent = ClipComponent.rectangle(
      position: Vector2(10, _plyHandZoneY + _viewScrollY),
      size: Vector2(size.x - 20, _plyHandZoneH),
    );
    add(_handClipComponent);
  }

  // 動的に計算するゾーン幅
  double get _plyBoardZoneWidth => size.x - _plyBoardX - 10;
  double get _oppBoardZoneWidth => size.x - _oppBoardX - (_domainW + 20);
  double get _oppDomainX => size.x - 10 - _domainW;

  @override
  void update(double dt) {
    super.update(dt);
    // ClipComponent の縦位置を毎フレーム同期
    _boardClipComponent.position = Vector2(_plyBoardX, _plyFieldY + _viewScrollY);
    _handClipComponent.position = Vector2(10, _plyHandZoneY + _viewScrollY);
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
      ..color = material.Colors.white.withOpacity(0.018);
    const gridSize = 40.0;
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(
          material.Offset(x, 0), material.Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(
          material.Offset(0, y), material.Offset(size.x, y), gridPaint);
    }

    // ─── 相手エリア ───────────────────────────────────────────
    if (opponentAreaVisible) {
      _renderOpponentArea(canvas);
    }

    // ─── セパレーター ─────────────────────────────────────────
    canvas.drawLine(
      material.Offset(0, _separatorY + _viewScrollY),
      material.Offset(size.x, _separatorY + _viewScrollY),
      material.Paint()
        ..color = GameTheme.zoneBorder.withOpacity(0.6)
        ..strokeWidth = 1.5,
    );

    // ─── 自分フィールドゾーン ─────────────────────────────────
    _renderZone(
      canvas,
      material.Rect.fromLTWH(_plyDomainX, _plyFieldY + _viewScrollY, _domainW, _fieldH),
      GameTheme.domainZoneBg,
      'ドメイン',
    );
    _renderZone(
      canvas,
      material.Rect.fromLTWH(_plyBoardX, _plyFieldY + _viewScrollY, _plyBoardZoneWidth, _fieldH),
      GameTheme.boardZoneBg,
      'フィールド',
    );

    // ─── 自分手札ゾーン ───────────────────────────────────────
    _renderZone(
      canvas,
      material.Rect.fromLTWH(10, _plyHandZoneY + _viewScrollY, size.x - 20, _plyHandZoneH),
      GameTheme.handZoneBg,
      '手札',
    );

    // ─── 自分 HUD ─────────────────────────────────────────────
    _renderPlayerHud(canvas);

    super.render(canvas); // 子コンポーネント（カード・ClipComponent）の描画
  }

  // ─── 相手エリア ───────────────────────────────────────────────

  void _renderOpponentArea(material.Canvas canvas) {
    final state = gameRef.gameState;
    final s = _viewScrollY;

    // 相手 HUD（ライフ・手札枚数・デッキ枚数・墓地枚数）
    _renderPill(canvas, '♥ ${state.opponentLife}',
        material.Offset(10, _oppHudY + s), GameTheme.hudLifeColor);
    _renderPill(canvas, '🂠 ${state.opponentHandCount}',
        material.Offset(110, _oppHudY + s), GameTheme.hudDimColor);
    _renderPill(canvas, '📦 40',
        material.Offset(180, _oppHudY + s), GameTheme.hudDimColor);
    _renderPill(canvas, '☠ 0',
        material.Offset(235, _oppHudY + s), GameTheme.hudDimColor);

    // 相手手札ゾーン（裏向きカード）
    _renderZone(
      canvas,
      material.Rect.fromLTWH(10, _oppHandZoneY + s, size.x - 20, _oppHandZoneH),
      GameTheme.handZoneBg,
      '相手の手札',
    );
    _renderOpponentHand(canvas, state.opponentHandCount);

    // 相手フィールド：ボード（左）・ドメイン（右）— 点対称
    _renderZone(
      canvas,
      material.Rect.fromLTWH(_oppBoardX, _oppFieldY + s, _oppBoardZoneWidth, _fieldH),
      GameTheme.boardZoneBg,
      '相手のフィールド',
    );
    _renderZone(
      canvas,
      material.Rect.fromLTWH(_oppDomainX, _oppFieldY + s, _domainW, _fieldH),
      GameTheme.domainZoneBg,
      '相手のドメイン',
    );
  }

  void _renderOpponentHand(material.Canvas canvas, int count) {
    final displayCount = min(count, 7);
    // 右から左に並べる（点対称: 自分の手札は左から右）
    final cardY = _oppHandZoneY + (_oppHandZoneH - _cardH) / 2 + _viewScrollY;
    for (int i = 0; i < displayCount; i++) {
      final cardX = size.x - 15 - _cardW - i * 108.0;
      if (cardX < 15) break;
      _renderFaceDownCard(
        canvas,
        material.Rect.fromLTWH(cardX, cardY, _cardW, _cardH),
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
    final state = gameRef.gameState;
    final hudY = _plyHudY + _viewScrollY;

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
          color: GameTheme.hudDimColor.withOpacity(0.7),
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
    canvas.drawRRect(pillRect, material.Paint()..color = color.withOpacity(0.15));
    canvas.drawRRect(
      pillRect,
      material.Paint()
        ..color = color.withOpacity(0.4)
        ..style = material.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas, pos);
  }

  // ─── 手札の差分更新 ──────────────────────────────────────────

  void _updateHand() {
    final state = gameRef.gameState;
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
      final totalW = 15 + state.hand.count * 112.0 - 12.0;
      final handZoneW = size.x - 20;
      final overflow = totalW - handZoneW;
      final minScroll = overflow > 0 ? -overflow : 0.0;
      _handScrollX = _handScrollX.clamp(minScroll, 0.0);
    } else {
      _handScrollX = 0.0;
    }

    // 手札カードを追加・位置更新（ClipComponent内ローカル座標）
    final cardY = (_plyHandZoneH - _cardH) / 2; // clip 内中央
    for (int i = 0; i < state.hand.count; i++) {
      final card = state.hand.cards[i];
      final targetPos = Vector2(_handScrollX + 15 + i * 112.0, cardY);

      if (_handComponentMap.containsKey(card.instanceId)) {
        _handComponentMap[card.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: card,
          position: targetPos,
          onTap: () {
            final sel = gameRef.gameState.selectedCard.value;
            if (sel?.card.instanceId == card.instanceId) {
              final idx = gameRef.gameState.hand.cards
                  .indexWhere((c) => c.instanceId == card.instanceId);
              if (idx == -1) return;
              gameRef.gameState.selectCard(null);
              gameRef.playCardFromHand(idx);
            } else {
              final idx = gameRef.gameState.hand.cards
                  .indexWhere((c) => c.instanceId == card.instanceId);
              if (idx == -1) return;
              gameRef.gameState.selectCard(CardSelectionState(
                card: card,
                zone: SelectionZone.hand,
                handIndex: idx,
              ));
            }
          },
        );
        _handComponentMap[card.instanceId] = component;
        _handClipComponent.add(component);
      }
    }
  }

  // ─── フィールドの差分更新 ─────────────────────────────────────

  void _updateField() {
    final state = gameRef.gameState;

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
        _plyDomainX + (_domainW - _cardW) / 2,
        _plyFieldY + (_fieldH - _cardH) / 2 + _viewScrollY,
      );
      if (_domainComponentMap.containsKey(domainCard.instanceId)) {
        _domainComponentMap[domainCard.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: domainCard,
          position: targetPos,
          isField: true,
          onTap: () {
            gameRef.gameState.selectCard(CardSelectionState(
              card: domainCard,
              zone: SelectionZone.board,
            ));
          },
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
      final totalW = state.board.count * 112.0 - 12.0;
      final overflow = totalW - _plyBoardZoneWidth;
      final minScroll = overflow > 0 ? -overflow : 0.0;
      _boardScrollX = _boardScrollX.clamp(minScroll, 0.0);
    } else {
      _boardScrollX = 0.0;
    }

    // ボードカード追加/位置更新（ClipComponent内ローカル座標）
    final cardY = (_fieldH - _cardH) / 2; // ClipComponent内で縦中央
    for (int i = 0; i < state.board.count; i++) {
      final boardCard = state.board.cards[i];
      final targetPos = Vector2(_boardScrollX + i * 112.0, cardY);
      final hasActivated = boardCard.card.abilities
          .any((a) => a.when == TriggerWhen.activated);

      if (_boardCardComponentMap.containsKey(boardCard.instanceId)) {
        _boardCardComponentMap[boardCard.instanceId]!.position = targetPos;
      } else {
        final component = CardComponent(
          card: boardCard,
          position: targetPos,
          isField: true,
          onTap: () {
            final sel = gameRef.gameState.selectedCard.value;
            if (hasActivated &&
                sel?.card.instanceId == boardCard.instanceId) {
              gameRef.gameState.selectCard(null);
              gameRef.activateCardOnBoard(boardCard);
            } else {
              gameRef.gameState.selectCard(CardSelectionState(
                card: boardCard,
                zone: SelectionZone.board,
              ));
            }
          },
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

    final queue = gameRef.gameState.triggerQueue.toList();
    if (queue.isEmpty) return;

    final queueTitle = TextComponent(
      text: 'キュー:',
      position: Vector2(size.x - 180, _separatorY + _viewScrollY + 10),
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
        position: Vector2(size.x - 180, _separatorY + _viewScrollY + 26 + i * 18),
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
    final adjustedY = pos.y - _viewScrollY;
    final boardRect = material.Rect.fromLTWH(
        _plyBoardX, _plyFieldY, _plyBoardZoneWidth, _fieldH);
    final handRect = material.Rect.fromLTWH(
        10, _plyHandZoneY, size.x - 20, _plyHandZoneH);
    _dragIsInBoardZone =
        boardRect.contains(material.Offset(pos.x, adjustedY));
    _dragIsInHandZone =
        handRect.contains(material.Offset(pos.x, adjustedY));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragIsInBoardZone) {
      _boardScrollX += event.localDelta.x;
    } else if (_dragIsInHandZone) {
      _handScrollX += event.localDelta.x;
    } else {
      // 縦スクロール
      _viewScrollY += event.localDelta.y;
      _clampViewScrollY();
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragIsInBoardZone = false;
    _dragIsInHandZone = false;
  }

  // ─── 空白タップで選択解除 ─────────────────────────────────────

  @override
  bool onTapDown(TapDownEvent event) {
    gameRef.gameState.selectCard(null);
    return false;
  }
}
