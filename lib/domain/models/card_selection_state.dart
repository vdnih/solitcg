import 'card_instance.dart';

/// カードが選択されているゾーンを表す列挙型。
enum SelectionZone { hand, board }

/// ゲーム中にカードが選択された状態を表すデータクラス。
/// GameState.selectedCard (ValueNotifier) で保持され、Flutter UI の詳細パネル表示に使用する。
class CardSelectionState {
  final CardInstance card;
  final SelectionZone zone;

  /// zone == SelectionZone.hand のとき、手札内のインデックス。
  final int? handIndex;

  const CardSelectionState({
    required this.card,
    required this.zone,
    this.handIndex,
  });
}
