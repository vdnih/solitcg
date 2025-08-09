import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'types.dart';

class CardLoader {
  static CardType? _parseCardType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'monster':
        return CardType.monster;
      case 'spell':
        return CardType.spell;
      case 'equip':
        return CardType.equip;
      case 'artifact':
        return CardType.artifact;
      case 'field':
        return CardType.field;
      default:
        return null;
    }
  }

  static TriggerWhen? _parseTriggerWhen(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'on_play':
        return TriggerWhen.onPlay;
      case 'on_enter':
        return TriggerWhen.onEnter;
      case 'on_destroy':
        return TriggerWhen.onDestroy;
      case 'static':
        return TriggerWhen.static;
      case 'activated':
        return TriggerWhen.activated;
      case 'on_draw':
        return TriggerWhen.onDraw;
      case 'on_discard':
        return TriggerWhen.onDiscard;
      case 'on_field_set':
        return TriggerWhen.onFieldSet;
      default:
        return null;
    }
  }

  static Stats? _parseStats(dynamic statsData) {
    if (statsData == null) return null;
    if (statsData is! Map) return null;
    
    final atk = statsData['atk'] as int? ?? 0;
    final hp = statsData['hp'] as int? ?? 0;
    return Stats(atk: atk, hp: hp);
  }

  static EquipConfig? _parseEquipConfig(dynamic equipData) {
    if (equipData == null) return null;
    if (equipData is! Map) return null;
    
    final validTargets = equipData['valid_targets'];
    if (validTargets is List) {
      return EquipConfig(validTargets: validTargets.cast<String>());
    }
    return null;
  }

  static FieldConfig? _parseFieldConfig(dynamic fieldData) {
    if (fieldData == null) return null;
    if (fieldData is! Map) return null;
    
    final unique = fieldData['unique'] as bool? ?? true;
    return FieldConfig(unique: unique);
  }

  static List<EffectStep> _parseEffects(dynamic effectsData) {
    if (effectsData == null) return [];
    if (effectsData is! List) return [];
    
    final effects = <EffectStep>[];
    for (final effectData in effectsData) {
      if (effectData is Map) {
        final op = effectData['op'] as String?;
        if (op != null) {
          final params = Map<String, dynamic>.from(effectData);
          params.remove('op');
          effects.add(EffectStep(op: op, params: params));
        }
      }
    }
    return effects;
  }

  static List<Ability> _parseAbilities(dynamic abilitiesData) {
    if (abilitiesData == null) return [];
    if (abilitiesData is! List) return [];
    
    final abilities = <Ability>[];
    for (final abilityData in abilitiesData) {
      if (abilityData is Map) {
        final whenStr = abilityData['when'] as String?;
        final when = _parseTriggerWhen(whenStr);
        if (when != null) {
          final condition = abilityData['condition'] as String?;
          final priority = abilityData['priority'] as int? ?? 0;
          final effects = _parseEffects(abilityData['effect']);
          
          abilities.add(Ability(
            when: when,
            condition: condition,
            priority: priority,
            effects: effects,
          ));
        }
      }
    }
    return abilities;
  }

  static Card? parseCard(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! Map) return null;

      final id = doc['id'] as String?;
      final name = doc['name'] as String?;
      final typeStr = doc['type'] as String?;
      final type = _parseCardType(typeStr);

      if (id == null || name == null || type == null) {
        return null;
      }

      final tags = doc['tags'] is List 
          ? (doc['tags'] as List).cast<String>() 
          : <String>[];
      final text = doc['text'] as String? ?? '';
      final version = doc['version'] as int? ?? 1;
      
      final stats = _parseStats(doc['stats']);
      final equip = _parseEquipConfig(doc['equip']);
      final field = _parseFieldConfig(doc['field']);
      final abilities = _parseAbilities(doc['abilities']);

      return Card(
        id: id,
        name: name,
        type: type,
        tags: tags,
        text: text,
        version: version,
        stats: stats,
        equip: equip,
        field: field,
        abilities: abilities,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<Card?> loadCardFromAsset(String assetPath) async {
    try {
      final yamlContent = await rootBundle.loadString(assetPath);
      return parseCard(yamlContent);
    } catch (e) {
      return null;
    }
  }

  static Future<List<String>> loadCardIndex() async {
    try {
      final yamlContent = await rootBundle.loadString('assets/cards/index.yaml');
      final doc = loadYaml(yamlContent);
      if (doc is Map && doc['cards'] is List) {
        return (doc['cards'] as List).cast<String>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Card>> loadAllCards() async {
    final cardFiles = await loadCardIndex();
    final cards = <Card>[];
    
    for (final cardFile in cardFiles) {
      final card = await loadCardFromAsset('assets/cards/$cardFile');
      if (card != null) {
        cards.add(card);
      }
    }
    
    return cards;
  }

  static bool validateCard(Card card) {
    if (card.id.isEmpty || card.name.isEmpty) return false;
    
    switch (card.type) {
      case CardType.monster:
        if (card.stats == null) return false;
        break;
      case CardType.equip:
        if (card.equip == null) return false;
        break;
      case CardType.field:
        break;
      default:
        break;
    }
    
    for (final ability in card.abilities) {
      for (final effect in ability.effects) {
        if (effect.op.isEmpty) return false;
      }
    }
    
    return true;
  }
}