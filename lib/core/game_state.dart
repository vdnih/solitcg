import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../domain/models/card_selection_state.dart';
import '../domain/models/choice_request.dart';
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

  /// このターンに activated 能力を使用したカードの instanceId セット。
  /// ドローフェイズ開始時にクリアする。
  final Set<String> activatedThisTurn = {};
  int playerLife = 8000;
  int opponentLife = 8000;
  int opponentHandCount = 5;
  bool gameWon = false;
  bool gameLost = false;

  final Queue<Trigger> triggerQueue = Queue<Trigger>();
  final ValueNotifier<List<String>> actionLogNotifier = ValueNotifier([]);
  List<String> get actionLog => actionLogNotifier.value;

  final ValueNotifier<ChoiceRequest?> choiceRequest = ValueNotifier(null);

  /// 現在選択中のカード状態。Flutter UI の詳細パネル表示に使用する。
  final ValueNotifier<CardSelectionState?> selectedCard = ValueNotifier(null);

  /// カードの選択状態を更新する。null を渡すと選択解除。
  void selectCard(CardSelectionState? selection) {
    selectedCard.value = selection;
  }

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
    actionLogNotifier.value = [...actionLogNotifier.value, message];
  }

  void addAllToLog(List<String> messages) {
    if (messages.isEmpty) return;
    actionLogNotifier.value = [...actionLogNotifier.value, ...messages];
  }

  bool get isGameOver => gameWon || gameLost;

  CardInstance? get currentDomain => domain.first;
  bool get hasDomain => domain.isNotEmpty;
}