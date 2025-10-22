import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' as material;
import '../../domain/models/card_data.dart';
import '../../domain/models/card_instance.dart';

/// カードの見た目を描画し、タップイベントを処理するコンポーネント。
///
/// このコンポーネントはカードの「状態」や「ロジック」を持たず、
/// 与えられた `CardInstance` に基づいて自身を描画することに専念します。
class CardComponent extends PositionComponent with TapCallbacks {
  /// 描画対象のカードインスタンス。
  final CardInstance card;

  /// カードがタップされたときに実行されるコールバック関数。
  final material.VoidCallback? onTap;

  /// フィールド上のカードかどうか。描画に影響を与える可能性があります。
  final bool isField;

  CardComponent({
    required this.card,
    required Vector2 position,
    this.onTap,
    this.isField = false,
  }) : super(
          position: position,
          size: Vector2(100, 140), // カードの固定サイズ
        );

  /// カードの種類に基づいてベースカラーを決定します。
  material.Color _getCardBaseColor() {
    switch (card.card.type) {
      case CardType.monster:
        return material.Colors.brown.shade700;
      case CardType.ritual:
        return material.Colors.purple.shade700;
      case CardType.spell:
        return material.Colors.green.shade700;
      case CardType.arcane:
        return material.Colors.teal.shade700;
      case CardType.artifact:
        return material.Colors.orange.shade700;
      case CardType.relic:
        return material.Colors.deepOrange.shade700;
      case CardType.equip:
        return material.Colors.yellow.shade700;
      case CardType.domain:
        return material.Colors.blue.shade700;
      default:
        return material.Colors.grey.shade700;
    }
  }

  /// カードの種類に基づいて内側のカラーを決定します。
  material.Color _getCardInnerColor() {
    switch (card.card.type) {
      case CardType.monster:
        return material.Colors.brown.shade300;
      case CardType.ritual:
        return material.Colors.purple.shade300;
      case CardType.spell:
        return material.Colors.green.shade300;
      case CardType.arcane:
        return material.Colors.teal.shade300;
      case CardType.artifact:
        return material.Colors.orange.shade300;
      case CardType.relic:
        return material.Colors.deepOrange.shade300;
      case CardType.equip:
        return material.Colors.yellow.shade300;
      case CardType.domain:
        return material.Colors.blue.shade300;
      default:
        return material.Colors.grey.shade300;
    }
  }

  @override
  void render(material.Canvas canvas) {
    super.render(canvas);

    // カードのベース（外枠）を描画
    canvas.drawRRect(
      material.RRect.fromRectAndRadius(
        material.Rect.fromLTWH(0, 0, size.x, size.y),
        const material.Radius.circular(8),
      ),
      material.Paint()
        ..color = _getCardBaseColor()
        ..style = material.PaintingStyle.fill,
    );

    // カードの内側を描画
    canvas.drawRRect(
      material.RRect.fromRectAndRadius(
        material.Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
        const material.Radius.circular(6),
      ),
      material.Paint()
        ..color = _getCardInnerColor()
        ..style = material.PaintingStyle.fill,
    );

    // カード名を描画
    final textPainter = material.TextPainter(
      text: material.TextSpan(
        text: card.card.name,
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 10,
          fontWeight: material.FontWeight.bold,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.x - 8);
    textPainter.paint(canvas, const material.Offset(4, 4));

    // カード種別を描画
    final typePainter = material.TextPainter(
      text: material.TextSpan(
        text: card.card.type.toString().split('.').last,
        style: const material.TextStyle(
          color: material.Colors.white70,
          fontSize: 8,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    );
    typePainter.layout();
    typePainter.paint(canvas, material.Offset(4, size.y - 16));

    // モンスターとリチュアルのステータスを描画
    if (card.card.type == CardType.monster ||
        card.card.type == CardType.ritual) {
      if (card.stats != null) {
        final statsPainter = material.TextPainter(
          text: material.TextSpan(
            text:
                'ATK: ${card.stats.atk} | DEF: ${card.stats.def} | HP: ${card.stats.hp}',
            style: const material.TextStyle(
              color: material.Colors.white,
              fontSize: 8,
            ),
          ),
          textDirection: material.TextDirection.ltr,
        );
        statsPainter.layout(maxWidth: size.x - 8);
        statsPainter.paint(canvas, material.Offset(4, size.y - 28));
      }
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // onTap コールバックが設定されていれば実行する
    if (onTap != null) {
      onTap!();
      return true; // イベントを消費
    }
    return false; // イベントを伝播
  }
}