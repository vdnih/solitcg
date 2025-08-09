import 'dart:collection';

enum CardType { monster, spell, equip, artifact, field }

enum TriggerWhen { onPlay, onEnter, onDestroy, static, activated, onDraw, onDiscard, onFieldSet }

enum Zone { hand, deck, field, grave, banish }

class Stats {
  final int atk;
  final int hp;

  const Stats({required this.atk, required this.hp});

  Stats copyWith({int? atk, int? hp}) {
    return Stats(atk: atk ?? this.atk, hp: hp ?? this.hp);
  }
}

class EquipConfig {
  final List<String> validTargets;

  const EquipConfig({required this.validTargets});
}

class FieldConfig {
  final bool unique;

  const FieldConfig({this.unique = true});
}

class EffectStep {
  final String op;
  final Map<String, dynamic> params;

  const EffectStep({required this.op, required this.params});
}

class Ability {
  final TriggerWhen when;
  final String? condition;
  final int priority;
  final List<EffectStep> effects;

  const Ability({
    required this.when,
    this.condition,
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
  final FieldConfig? field;
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
    this.field,
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

  Stats get stats => currentStats ?? card.stats ?? const Stats(atk: 0, hp: 0);
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
  final GameZone field;
  final GameZone grave;
  final GameZone banish;
  
  int spellsCastThisTurn = 0;
  bool gameWon = false;
  bool gameLost = false;
  
  final Queue<Trigger> triggerQueue = Queue<Trigger>();
  final List<String> actionLog = [];
  
  int _nextInstanceId = 1;
  int _triggerOrder = 0;

  GameState()
      : hand = GameZone(type: Zone.hand),
        deck = GameZone(type: Zone.deck),
        field = GameZone(type: Zone.field),
        grave = GameZone(type: Zone.grave),
        banish = GameZone(type: Zone.banish);

  GameZone getZone(Zone zone) {
    switch (zone) {
      case Zone.hand:
        return hand;
      case Zone.deck:
        return deck;
      case Zone.field:
        return field;
      case Zone.grave:
        return grave;
      case Zone.banish:
        return banish;
    }
  }

  String generateInstanceId() => 'inst_${_nextInstanceId++}';
  
  int getNextTriggerOrder() => ++_triggerOrder;

  void addToLog(String message) {
    actionLog.add(message);
  }

  bool get isGameOver => gameWon || gameLost;

  CardInstance? get currentField => field.first;
  bool get hasField => field.isNotEmpty;
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