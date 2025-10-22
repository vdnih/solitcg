import './card_data.dart';

/// フィールド上に存在するカードのインスタンス。
class CardInstance {
  final CardData card;
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