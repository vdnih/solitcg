import 'dart:math';

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
    for (final card in cards) {
      if (test(card)) return card;
    }
    return null;
  }

  /// Fisher-Yates アルゴリズムでゾーン内のカードをシャッフルする。
  void shuffle({Random? random}) {
    final rng = random ?? Random();
    for (int i = cards.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
  }
}
