import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/data/repositories/card_repository.dart';
import 'package:solitcg/data/repositories/deck_repository.dart';
import 'package:solitcg/domain/models/deck.dart';

void main() {
  // rootBundle は CachingAssetBundle のためテスト間で内部キャッシュが共有される。
  // 複数の testWidgets に分けて 'flutter/assets' ハンドラを都度差し替えると
  // 2つ目以降の呼び出しがハングするため、1つの test にまとめて検証する。
  testWidgets(
      'DeckRepository.loadSampleDeckMahou は assets/decks/sample.yaml を読み込み、'
      'assets/cards の全カードIDを網羅する', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final file = File(key);
      if (!file.existsSync()) return null;
      return ByteData.sublistView(utf8.encode(file.readAsStringSync()));
    });

    final allCards = await CardRepository.loadAllCards();
    final deck = await DeckRepository.loadSampleDeckMahou();

    expect(deck.id, 'sample_mahou_sho');
    expect(deck.type, DeckType.main);
    expect(deck.isReadOnly, isTrue);
    expect(deck.cardCount, greaterThanOrEqualTo(40));

    final deckCardIds = deck.cardIds.toSet();
    final allCardIds = allCards.map((c) => c.id).toSet();
    expect(deckCardIds, allCardIds);

    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });
}
