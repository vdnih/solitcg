import 'dart:collection';

enum CardType { monster, ritual, spell, arcane, artifact, relic, equip, domain }

enum TriggerWhen { onPlay, onDestroy, activated, static, onDraw, onDiscard }

enum Zone { hand, deck, board, domain, grave, extra }

class Stats {
  final int atk;
  final int def;
  final int hp;

  const Stats({required this.atk, required this.def, required this.hp});

  Stats copyWith({int? atk, int? def, int? hp}) {
    return Stats(
      atk: atk ?? this.atk,
      def: def ?? this.def,
      hp: hp ?? this.hp,
    );
  }
}

class EquipConfig {
  final List<String> validTargets;

  const EquipConfig({required this.validTargets});
}

class DomainConfig {
  final bool unique;

  const DomainConfig({this.unique = true});
}

class EffectStep {
  final String op;
  final Map<String, dynamic> params;

  const EffectStep({required this.op, required this.params});
}

class Ability {
  final TriggerWhen when;
  final List<String>? pre;
  final int priority;
  final List<EffectStep> effects;

  const Ability({
    required this.when,
    this.pre,
    this.priority = 0,
    required this.effects,
  });
}

class Card {
  final String id;
  final String name;
  final CardType type;
  final List<String> tags;
  final String text;
  final int version;
  final Stats? stats;
  final EquipConfig? equip;
  final DomainConfig? domain;
  final List<Ability> abilities;

  const Card({
    required this.id,
    required this.name,
    required this.type,
    this.tags = const [],
    this.text = '',
    this.version = 1,
    this.stats,
    this.equip,
    this.domain,
    this.abilities = const [],
  });
}

class CardInstance {
  final Card card;
  final String instanceId;
  Stats? currentStats;
  Map<String, dynamic> metadata;

  CardInstance({
    required this.card,
    required this.instanceId,
    this.currentStats,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Stats get stats => currentStats ?? card.stats ?? const Stats(atk: 0, def: 0, hp: 0);
}

class Trigger {
  final String id;
  final CardInstance source;
  final Ability ability;
  final int order;
  final Map<String, dynamic> context;

  Trigger({
    required this.id,
    required this.source,
    required this.ability,
    required this.order,
    this.context = const {},
  });
}

class GameZone {
  final Zone type;
  final List<CardInstance> cards;

  GameZone({required this.type, List<CardInstance>? cards}) : cards = cards ?? [];

  void add(CardInstance card) => cards.add(card);
  void addAll(List<CardInstance> newCards) => cards.addAll(newCards);
  bool remove(CardInstance card) => cards.remove(card);
  CardInstance? removeAt(int index) => index < cards.length ? cards.removeAt(index) : null;
  void insert(int index, CardInstance card) => cards.insert(index, card);
  void clear() => cards.clear();

  int get count => cards.length;
  bool get isEmpty => cards.isEmpty;
  bool get isNotEmpty => cards.isNotEmpty;

  CardInstance? get first => cards.isNotEmpty ? cards.first : null;
  CardInstance? get last => cards.isNotEmpty ? cards.last : null;

  List<CardInstance> where(bool Function(CardInstance) test) => cards.where(test).toList();
  CardInstance? firstWhere(bool Function(CardInstance) test) {
    try {
      return cards.firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

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

class GameResult {
  final bool success;
  final String? error;
  final List<String> logs;

  const GameResult({required this.success, this.error, this.logs = const []});

  factory GameResult.success({List<String> logs = const []}) {
    return GameResult(success: true, logs: logs);
  }

  factory GameResult.failure(String error, {List<String> logs = const []}) {
    return GameResult(success: false, error: error, logs: logs);
  }
}