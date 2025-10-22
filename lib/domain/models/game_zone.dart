import './card_instance.dart';

/// ゲーム内でカードが存在する領域。
enum Zone { hand, deck, board, domain, grave, extra }

/// 各ゾーン（手札・デッキ等）を表すコンテナ。
class GameZone {
  final Zone type;
  final List<CardInstance> cards;

  GameZone({required this.type, List<CardInstance>? cards}) : cards = cards ?? [];

  void add(CardInstance card) => cards.add(card);
  void addAll(List<CardInstance> newCards) => cards.addAll(newCards);
  bool remove(CardInstance card) => cards.remove(card);
  CardInstance? removeAt(int index) => index >= 0 && index < cards.length ? cards.removeAt(index) : null;
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
