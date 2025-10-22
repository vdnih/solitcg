import 'dart:collection';

import '../domain/models/trigger.dart';
import '../domain/models/game_zone.dart';
import '../domain/models/card_instance.dart';

/// ゲーム全体の状態を保持する。
class GameState {
  final GameZone hand;
  final GameZone deck;
  final GameZone board;
  final GameZone domain;
  final GameZone grave;
  final GameZone extra;
  
  int spellsCastThisTurn = 0;
  int playerLife = 8000;
  int opponentLife = 8000;
  bool gameWon = false;
  bool gameLost = false;
  
  final Queue<Trigger> triggerQueue = Queue<Trigger>();
  final List<String> actionLog = [];
  
  int _nextInstanceId = 1;
  int _triggerOrder = 0;

  GameState()
      : hand = GameZone(type: Zone.hand),
        deck = GameZone(type: Zone.deck),
        board = GameZone(type: Zone.board),
        domain = GameZone(type: Zone.domain),
        grave = GameZone(type: Zone.grave),
        extra = GameZone(type: Zone.extra);

  GameZone getZone(Zone zone) {
    switch (zone) {
      case Zone.hand:
        return hand;
      case Zone.deck:
        return deck;
      case Zone.board:
        return board;
      case Zone.domain:
        return domain;
      case Zone.grave:
        return grave;
      case Zone.extra:
        return extra;
    }
  }

  String generateInstanceId() => 'inst_${_nextInstanceId++}';
  
  int getNextTriggerOrder() => ++_triggerOrder;

  void addToLog(String message) {
    actionLog.add(message);
  }

  bool get isGameOver => gameWon || gameLost;

  CardInstance? get currentDomain => domain.first;
  bool get hasDomain => domain.isNotEmpty;
}
