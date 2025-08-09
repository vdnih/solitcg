import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart' as flame;
import 'package:flutter/material.dart' as material;
import '../engine/types.dart';
import '../engine/field_rule.dart';
import '../engine/stack.dart';
import 'dart:math';

class TCGGame extends FlameGame with TapDetector {
  late GameState gameState;
  final List<TextComponent> logComponents = [];
  final List<CardComponent> handComponents = [];
  late TextComponent gameStatusComponent;
  late TextComponent instructionComponent;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    gameState = GameState();
    await _initializeGame();
    _setupUI();
  }

  Future<void> _initializeGame() async {
    final sampleCards = _createSampleCards();
    
    for (final card in sampleCards) {
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

  List<Card> _createSampleCards() {
    return [
      Card(
        id: 'fld_x01',
        name: '残響の講堂',
        type: CardType.field,
        text: '場に出た時、カードを2枚引く。',
        abilities: [
          Ability(
            when: TriggerWhen.onPlay,
            effects: [EffectStep(op: 'draw', params: {'count': 2})],
          ),
          Ability(
            when: TriggerWhen.onDestroy,
            effects: [EffectStep(op: 'search', params: {'from': 'deck', 'to': 'hand', 'filter': {'type': 'field'}, 'max': 1})],
          ),
        ],
      ),
      Card(
        id: 'fld_x02',
        name: '記憶の温室',
        type: CardType.field,
        text: '場に出た時、スペルカードを1枚手札に加える。',
        abilities: [
          Ability(
            when: TriggerWhen.onPlay,
            effects: [EffectStep(op: 'search', params: {'from': 'deck', 'to': 'hand', 'filter': {'type': 'spell'}, 'max': 1})],
          ),
          Ability(
            when: TriggerWhen.onDestroy,
            effects: [EffectStep(op: 'draw', params: {'count': 1})],
          ),
        ],
      ),
      Card(
        id: 'spl_x07',
        name: '閃考の儀',
        type: CardType.spell,
        text: '手札を1枚捨てる。スペルを7回詠唱していたなら勝利。',
        abilities: [
          Ability(
            when: TriggerWhen.onPlay,
            effects: [
              EffectStep(op: 'discard', params: {'from': 'hand', 'count': 1}),
              EffectStep(op: 'win_if', params: {'expr': 'spells_cast_this_turn >= 7'}),
            ],
          ),
        ],
      ),
    ];
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
    
    _updateDisplay();
  }

  String _getGameStatusText() {
    return 'Hand: ${gameState.hand.count} | Deck: ${gameState.deck.count} | Grave: ${gameState.grave.count} | Spells: ${gameState.spellsCastThisTurn}';
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
    if (gameState.hasField) {
      final fieldCard = gameState.currentField!;
      final component = CardComponent(
        card: fieldCard,
        position: Vector2(size.x / 2 - 60, 250),
        onTap: null,
        isField: true,
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
          style: const TextStyle(
            color: Colors.white,
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

    final CardInstance card;
    final material.VoidCallback? onTap;
    final bool isField;

    CardComponent({
      required this.card,
      required flame.Vector2 position,
      this.onTap,
      this.isField = false,
    }) : super(
      position: position,
      size: flame.Vector2(100, 140),
      paint: material.Paint()..color = isField ? material.Colors.blue : material.Colors.brown,
    );

    @override
    void render(material.Canvas canvas) {
    super.render(canvas);

      canvas.drawRRect(
        material.RRect.fromRectAndRadius(
          material.Rect.fromLTWH(0, 0, size.x, size.y),
          const material.Radius.circular(8),
        ),
        material.Paint()
          ..color = isField ? material.Colors.blue.shade700 : material.Colors.brown.shade700
          ..style = material.PaintingStyle.fill,
      );

      canvas.drawRRect(
        material.RRect.fromRectAndRadius(
          material.Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
          const material.Radius.circular(6),
        ),
        material.Paint()
          ..color = isField ? material.Colors.blue.shade300 : material.Colors.brown.shade300
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
          paint: material.Paint()..color = isField ? material.Colors.blue : material.Colors.brown,
        );

  @override
  void render(material.Canvas canvas) {
    super.render(canvas);

    canvas.drawRRect(
      material.RRect.fromRectAndRadius(
        material.Rect.fromLTWH(0, 0, this.size.x, this.size.y),
        const material.Radius.circular(8),
      ),
      material.Paint()
        ..color = isField ? material.Colors.blue.shade700 : material.Colors.brown.shade700
        ..style = material.PaintingStyle.fill,
    );

    canvas.drawRRect(
      material.RRect.fromRectAndRadius(
        material.Rect.fromLTWH(2, 2, this.size.x - 4, this.size.y - 4),
        const material.Radius.circular(6),
      ),
      material.Paint()
        ..color = isField ? material.Colors.blue.shade300 : material.Colors.brown.shade300
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
    textPainter.layout(maxWidth: this.size.x - 8);
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
    typePainter.paint(canvas, material.Offset(4, this.size.y - 16));
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