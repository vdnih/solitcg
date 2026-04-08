/// カードの種類。
enum CardType { monster, ritual, spell, arcane, artifact, relic, equip, domain }

/// アビリティの発動タイミング。
/// MVP スコープ: on_play / on_destroy / on_discard / activated の4種のみ。
enum TriggerWhen { onPlay, onDestroy, activated, onDiscard }

/// 攻撃力・防御力・HP を保持するステータス。
/// atk / def は効果参照用の任意フィールド（省略時は 0）。
/// hp のみ monster / ritual の必須フィールド。
class Stats {
  final int atk;
  final int def;
  final int hp;

  const Stats({this.atk = 0, this.def = 0, required this.hp});

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
  final List<EffectStep> effects;

  const Ability({
    required this.when,
    this.pre,
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

  /// カード画像のファイル名（例: "mon_warrior.png"）。
  /// assets/images/cards/ 以下に配置。null の場合は色付き矩形で代替表示。
  final String? image;

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
    this.image,
  });
}
