// ignore_for_file: deprecated_member_use
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' as material;
import '../../domain/models/card_data.dart';
import '../../domain/models/card_instance.dart';
import '../../presentation/game/tcg_game.dart';
import '../../ui/theme/game_theme.dart';

/// カードの見た目を描画し、タップイベントを処理するコンポーネント。
///
/// 描画は毎フレーム行われ、選択グローは GameState.selectedCard を参照して自動更新される。
/// カード画像がある場合は Sprite としてレンダリングし、ない場合はグラデーション矩形で代替する。
class CardComponent extends PositionComponent with TapCallbacks, HasGameRef<TCGGame> {
  /// 描画対象のカードインスタンス。
  final CardInstance card;

  /// カードがタップされたときに実行されるコールバック関数。
  final material.VoidCallback? onTap;

  /// フィールド上のカードかどうか。
  final bool isField;

  Sprite? _sprite;

  CardComponent({
    required this.card,
    required Vector2 position,
    this.onTap,
    this.isField = false,
  }) : super(
          position: position,
          size: Vector2(100, 140),
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (card.card.image != null) {
      try {
        _sprite = await gameRef.loadSprite('images/cards/${card.card.image}');
      } catch (_) {
        // 画像ロード失敗時はグラデーション矩形にフォールバック
      }
    }
  }

  bool get _isSelected =>
      gameRef.gameState.selectedCard.value?.card.instanceId == card.instanceId;

  @override
  void render(material.Canvas canvas) {
    super.render(canvas);

    final outerRect = material.Rect.fromLTWH(0, 0, size.x, size.y);
    final outerRRect = material.RRect.fromRectAndRadius(
      outerRect,
      const material.Radius.circular(8),
    );

    // 選択グロー（外枠ブラー）
    if (_isSelected) {
      canvas.drawRRect(
        outerRRect,
        material.Paint()
          ..color = GameTheme.selectionGlow.withOpacity(0.5)
          ..maskFilter = const material.MaskFilter.blur(material.BlurStyle.outer, 8),
      );
    }

    // カードのベース（グラデーション外枠）
    final gradColors = GameTheme.cardGradient(card.card.type);
    final shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      ui.Offset(0, size.y),
      gradColors,
    );
    canvas.drawRRect(
      outerRRect,
      material.Paint()..shader = shader,
    );

    // 内側の暗いパネル
    final innerRRect = material.RRect.fromRectAndRadius(
      material.Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
      const material.Radius.circular(6),
    );
    canvas.drawRRect(
      innerRRect,
      material.Paint()..color = gradColors[0].withOpacity(0.85),
    );

    // カード画像 or プレースホルダー（上部 55%）
    const imageTop = 18.0;
    final imageHeight = size.y * 0.52;
    final imageRect = material.Rect.fromLTWH(3, imageTop, size.x - 6, imageHeight);

    if (_sprite != null) {
      _sprite!.render(
        canvas,
        position: Vector2(imageRect.left, imageRect.top),
        size: Vector2(imageRect.width, imageRect.height),
      );
    } else {
      // グラデーションプレースホルダー
      final placeholderShader = ui.Gradient.linear(
        ui.Offset(imageRect.left, imageRect.top),
        ui.Offset(imageRect.right, imageRect.bottom),
        [gradColors[1].withOpacity(0.5), gradColors[0].withOpacity(0.3)],
      );
      canvas.drawRect(
        imageRect,
        material.Paint()..shader = placeholderShader,
      );
      // カード種別アイコン文字（プレースホルダー中央）
      final iconPainter = material.TextPainter(
        text: material.TextSpan(
          text: _cardTypeIcon(card.card.type),
          style: material.TextStyle(
            color: material.Colors.white.withOpacity(0.4),
            fontSize: 24,
          ),
        ),
        textDirection: material.TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        material.Offset(
          imageRect.left + (imageRect.width - iconPainter.width) / 2,
          imageRect.top + (imageRect.height - iconPainter.height) / 2,
        ),
      );
    }

    // カード名
    final namePainter = material.TextPainter(
      text: material.TextSpan(
        text: card.card.name,
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 9,
          fontWeight: material.FontWeight.bold,
          shadows: [
            material.Shadow(color: material.Colors.black, blurRadius: 2),
          ],
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    namePainter.layout(maxWidth: size.x - 8);
    namePainter.paint(canvas, const material.Offset(4, 4));

    // モンスター・リチュアルのステータス
    if (card.card.type == CardType.monster || card.card.type == CardType.ritual) {
      final s = card.stats;
      // ignore: unnecessary_null_comparison
      if (s != null) {
        _drawStatsBadge(canvas, 'ATK ${s.atk}', size.y - 38);
        _drawStatsBadge(canvas, 'DEF ${s.def}', size.y - 26);
        _drawStatsBadge(canvas, 'HP  ${s.hp}', size.y - 14);
      }
    } else {
      // 種別バッジ（下部）
      final typePainter = material.TextPainter(
        text: material.TextSpan(
          text: GameTheme.cardTypeName(card.card.type),
          style: material.TextStyle(
            color: GameTheme.cardAccentColor(card.card.type),
            fontSize: 7,
            fontWeight: material.FontWeight.w600,
          ),
        ),
        textDirection: material.TextDirection.ltr,
      );
      typePainter.layout();
      typePainter.paint(canvas, material.Offset(4, size.y - 13));
    }

    // カウンター表示（metadata に 1 以上の整数値があれば "・N" を描画）
    final counters = card.metadata.entries
        .where((e) => e.value is int && (e.value as int) > 0)
        .toList();
    if (counters.isNotEmpty) {
      final totalCount = counters.fold<int>(0, (sum, e) => sum + (e.value as int));
      final counterPainter = material.TextPainter(
        text: material.TextSpan(
          text: '・$totalCount',
          style: const material.TextStyle(
            color: material.Color(0xFFFBBF24),
            fontSize: 9,
            fontWeight: material.FontWeight.bold,
            shadows: [
              material.Shadow(color: material.Colors.black, blurRadius: 2),
            ],
          ),
        ),
        textDirection: material.TextDirection.ltr,
      );
      counterPainter.layout(maxWidth: size.x - 8);
      counterPainter.paint(canvas, material.Offset(4, size.y - 25));
    }

    // 選択中ゴールドボーダー
    if (_isSelected) {
      canvas.drawRRect(
        outerRRect,
        material.Paint()
          ..color = GameTheme.selectionBorder
          ..style = material.PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawStatsBadge(material.Canvas canvas, String text, double y) {
    final painter = material.TextPainter(
      text: material.TextSpan(
        text: text,
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 7,
          fontWeight: material.FontWeight.w500,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    painter.layout(maxWidth: size.x - 8);
    painter.paint(canvas, material.Offset(4, y));
  }

  String _cardTypeIcon(CardType type) {
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

  @override
  bool onTapDown(TapDownEvent event) {
    if (onTap != null) {
      onTap!();
      return true;
    }
    return false;
  }
}
