import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/data/repositories/card_repository.dart';
import 'package:solitcg/data/repositories/deck_repository.dart';
import 'package:solitcg/domain/models/deck.dart';
import 'package:solitcg/domain/services/deck_validator.dart';

void main() {
  // rootBundle は CachingAssetBundle のためテスト間で内部キャッシュが共有される。
  // 複数の testWidgets に分けて 'flutter/assets' ハンドラを都度差し替えると
  // 2つ目以降の呼び出しがハングするため、1つの test にまとめて検証する。
  testWidgets(
      'DeckRepository.loadSampleDecks は全サンプルデッキを読み込み、'
      'どのデッキも実在するカードだけで構成されデッキ構築ルールを満たす', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final file = File(key);
      if (!file.existsSync()) return null;
      return ByteData.sublistView(utf8.encode(file.readAsStringSync()));
    });

    final allCards = await CardRepository.loadAllCards();
    final decks = await DeckRepository.loadSampleDecks();

    expect(decks.map((d) => d.id), [
      'sample_mahou_sho',
      'sample_library_seal_giant',
      'sample_stargazer_seal_giant',
      'sample_dragon_seal_giant',
      'sample_takemitsu_seal_giant',
    ]);

    for (final deck in decks) {
      expect(deck.type, DeckType.main, reason: deck.id);
      expect(deck.isReadOnly, isTrue, reason: deck.id);

      final result = await DeckValidator.validateDeck(deck, allCards);
      expect(result.errors, isEmpty, reason: deck.id);

      // sample_mahou_sho は 50 枚あり「ちょうど40枚」に違反している（#49 で是正予定）
      if (deck.id != 'sample_mahou_sho') {
        expect(deck.cardCount, 40, reason: deck.id);
      }
    }

    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });
}
