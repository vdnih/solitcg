/// カードの種類。
enum CardType { monster, ritual, spell, arcane, artifact, relic, equip, domain }

/// アビリティの発動タイミング。
enum TriggerWhen { onPlay, onDestroy, activated, static, onDraw, onDiscard }

/// 攻撃力・防御力・HP を保持するステータス。
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

/// 装備カードの設定。
class EquipConfig {
  final List<String> validTargets;

  const EquipConfig({required this.validTargets});
}

/// ドメインカードの設定。
class DomainConfig {
  final bool unique;

  const DomainConfig({this.unique = true});
}

/// 効果の1ステップを表すデータ。
class EffectStep {
  final String op;
  final Map<String, dynamic> params;

  const EffectStep({required this.op, required this.params});
}

/// カードが持つアビリティ。
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

/// YAML から読み込まれるカードの静的データ。
class CardData {
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

  const CardData({
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
