import './card_data.dart';
import './card_instance.dart';

/// キューに積まれるトリガー情報。
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