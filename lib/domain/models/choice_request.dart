
import './card_data.dart';
import './game_zone.dart';

enum ChoiceType {
  discard,
}

class ChoiceRequest {
  final ChoiceType type;
  final int count;
  final GameZone fromZone;
  final List<EffectStep> pendingEffects;
  final String? message;

  ChoiceRequest({
    required this.type,
    required this.count,
    required this.fromZone,
    required this.pendingEffects,
    this.message,
  });
}
