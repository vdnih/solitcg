import './card_instance.dart';
import './card_data.dart';

enum ChoiceType {
  discard,
  move,
  destroy,
}

/// プレイヤーにカード選択を求めるリクエスト。
///
/// エンジンが複数の候補カードを特定し、プレイヤーが選ぶ必要があるときに
/// [GameState.choiceRequest] にセットされる。
/// UI は [candidates] を表示し、プレイヤーが [count] 枚選択して確定すると
/// [TCGGame.resolveChoice] が呼ばれてトリガー解決が再開される。
///
/// [pendingEffects] は、この選択が中断した時点のアビリティ内の残り effect。
/// 選択解決後に順次実行される。
class ChoiceRequest {
  final ChoiceType type;
  final int count;
  final List<CardInstance> candidates;
  final String sourceZone;
  final String? targetZone;
  final String? message;
  final List<EffectStep> pendingEffects;

  ChoiceRequest({
    required this.type,
    required this.count,
    required this.candidates,
    required this.sourceZone,
    this.targetZone,
    this.message,
    this.pendingEffects = const [],
  });
}
