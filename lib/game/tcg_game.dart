import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' as material;
import '../engine/types.dart';
import '../engine/field_rule.dart';
import '../engine/stack.dart';
import '../engine/loader.dart';
import 'dart:math';

class TCGGame extends FlameGame with TapDetector {
  late GameState gameState;
  final List<TextComponent> logComponents = [];
  final List<CardComponent> handComponents = [];
  late TextComponent gameStatusComponent;
  late TextComponent instructionComponent;
  late TextComponent lifeComponent;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    gameState = GameState();
    await _initializeGame();
    _setupUI();
  }

  Future<void> _initializeGame() async {
    final cards = await CardLoader.loadAllCards();
    
    if (cards.isEmpty) {
      gameState.addToLog('Failed to load cards from YAML files');
      return;
    }
    
    for (final card in cards) {
      gameState.deck.add(CardInstance(
        card: card,
        instanceId: gameState.generateInstanceId(),
      ));
    }
    
    _shuffleDeck();
    
    for (int i = 0; i < 5; i++) {
      if (gameState.deck.isNotEmpty) {
        final card = gameState.deck.removeAt(0);
        if (card != null) {
          gameState.hand.add(card);
        }
      }
    }
    
    gameState.addToLog('Game initialized with ${gameState.hand.count} cards in hand');
  }


  void _shuffleDeck() {
    final random = Random();
    for (int i = gameState.deck.count - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = gameState.deck.cards[i];
      gameState.deck.cards[i] = gameState.deck.cards[j];
      gameState.deck.cards[j] = temp;
    }
  }

  void _setupUI() {
    instructionComponent = TextComponent(
      text: 'Tap cards in your hand to play them',
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 16,
        ),
      ),
    );
    add(instructionComponent);
    
    gameStatusComponent = TextComponent(
      text: _getGameStatusText(),
      position: Vector2(20, 50),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.yellow,
          fontSize: 14,
        ),
      ),
    );
    add(gameStatusComponent);
    
    lifeComponent = TextComponent(
      text: 'Player Life: ${gameState.playerLife} | Opponent Life: ${gameState.opponentLife}',
      position: Vector2(size.x / 2 - 100, 20),
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.green,
          fontSize: 18,
          fontWeight: material.FontWeight.bold,
        ),
      ),
    );
    add(lifeComponent);
    
    _updateDisplay();
  }

  String _getGameStatusText() {
    return 'Hand: ${gameState.hand.count} | Deck: ${gameState.deck.count} | Grave: ${gameState.grave.count} | Life: ${gameState.playerLife} | Spells: ${gameState.spellsCastThisTurn}';
  }

  void _updateDisplay() {
    for (final component in handComponents) {
      remove(component);
    }
    handComponents.clear();

    for (final component in logComponents) {
      remove(component);
    }
    logComponents.clear();

    _updateHand();
    _updateField();
    _updateLog();
    
    gameStatusComponent.text = _getGameStatusText();
    lifeComponent.text = 'Player Life: ${gameState.playerLife} | Opponent Life: ${gameState.opponentLife}';
    
    if (gameState.gameWon) {
      add(TextComponent(
        text: 'VICTORY!',
        position: Vector2(size.x / 2 - 50, size.y / 2),
        textRenderer: TextPaint(
          style: const material.TextStyle(
            color: material.Colors.green,
            fontSize: 32,
            fontWeight: material.FontWeight.bold,
          ),
        ),
      ));
    }
  }

  void _updateHand() {
    for (int i = 0; i < gameState.hand.count; i++) {
      final card = gameState.hand.cards[i];
      final component = CardComponent(
        card: card,
        position: Vector2(20 + i * 120, 100),
        onTap: () => _playCard(i),
      );
      handComponents.add(component);
      add(component);
    }
  }

  void _updateField() {
    // Update domain (if exists)
    if (gameState.hasDomain) {
      final domainCard = gameState.currentDomain!;
      final component = CardComponent(
        card: domainCard,
        position: Vector2(size.x / 2 - 150, 250),
        onTap: null,
        isField: true,
      );
      add(component);
    }
    
    // Update board cards
    for (int i = 0; i < gameState.board.count; i++) {
      final boardCard = gameState.board.cards[i];
      final component = CardComponent(
        card: boardCard,
        position: Vector2(size.x / 2 - 50 + i * 70, 350),
        onTap: null,
        isField: false,
      );
      add(component);
    }
  }

  void _updateLog() {
    final recentLogs = gameState.actionLog.reversed.take(10).toList().reversed.toList();
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
      logComponents.add(logComponent);
      add(logComponent);
    }
  }

  void _playCard(int handIndex) {
    if (gameState.isGameOver) return;
    
    gameState.addToLog('Playing card at index $handIndex');
    
    final result = FieldRule.playCardFromHand(gameState, handIndex);
    if (!result.success) {
      gameState.addToLog('Failed to play card: ${result.error}');
      _updateDisplay();
      return;
    }
    
    gameState.actionLog.addAll(result.logs);
    
    final resolveResult = TriggerStack.resolveAll(gameState);
    gameState.actionLog.addAll(resolveResult.logs);
    
    if (!resolveResult.success) {
      gameState.addToLog('Resolution failed: ${resolveResult.error}');
    }
    
    _updateDisplay();
  }

  @override
  void render(material.Canvas canvas) {
    canvas.drawRect(
      material.Rect.fromLTWH(0, 0, size.x, size.y),
      material.Paint()..color = material.Colors.black87,
    );
    super.render(canvas);
  }
}

  // --- CardComponentクラス定義 ---
class CardComponent extends PositionComponent with TapCallbacks {

  final CardInstance card;
  final material.VoidCallback? onTap;
  final bool isField;

  CardComponent({
    required this.card,
    required Vector2 position,
    this.onTap,
    this.isField = false,
  }) : super(
          position: position,
          size: Vector2(100, 140),
        );

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

    canvas.drawRRect(
      material.RRect.fromRectAndRadius(
        material.Rect.fromLTWH(0, 0, size.x, size.y),
        const material.Radius.circular(8),
      ),
      material.Paint()
        ..color = _getCardBaseColor()
        ..style = material.PaintingStyle.fill,
    );

    canvas.drawRRect(
      material.RRect.fromRectAndRadius(
        material.Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
        const material.Radius.circular(6),
      ),
      material.Paint()
        ..color = _getCardInnerColor()
        ..style = material.PaintingStyle.fill,
    );

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
    
    // Display stats for monsters and rituals
    if (card.card.type == CardType.monster || card.card.type == CardType.ritual) {
      if (card.stats != null) {
        final statsPainter = material.TextPainter(
          text: material.TextSpan(
            text: 'ATK: ${card.stats.atk} | DEF: ${card.stats.def} | HP: ${card.stats.hp}',
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
    if (onTap != null) {
      onTap!();
      return true;
    }
    return false;
  }
}