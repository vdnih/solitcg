import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/data/repositories/card_repository.dart';
import 'package:solitcg/domain/models/card_data.dart';

void main() {
  // testWidgets を使用して、Flutterのバインディングを確実に初期化する
  testWidgets('CardRepository.loadAllCards loads and parses assets correctly', (WidgetTester tester) async {
    // Arrange: ダミーのYAMLコンテンツを定義
    const String indexYaml = '''
    cards:
      - card1.yaml
      - card2.yaml
    ''';

    const String card1Yaml = '''
    id: 'c001'
    name: 'Test Card 1'
    type: 'monster'
    stats:
      atk: 100
      def: 100
      hp: 100
    ''';

    const String card2Yaml = '''
    id: 'c002'
    name: 'Test Card 2'
    type: 'spell'
    ''';

    // Arrange: rootBundleからの応答をモック
    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final String key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'assets/cards/index.yaml') {
        return ByteData.sublistView(utf8.encode(indexYaml));
      }
      if (key == 'assets/cards/card1.yaml') {
        return ByteData.sublistView(utf8.encode(card1Yaml));
      }
      if (key == 'assets/cards/card2.yaml') {
        return ByteData.sublistView(utf8.encode(card2Yaml));
      }
      return null;
    });

    // Act: テスト対象のメソッドを実行
    final cards = await CardRepository.loadAllCards();

    // Assert: 結果を検証
    expect(cards.length, 2);
    expect(cards.any((c) => c.id == 'c001'), isTrue);
    expect(cards.any((c) => c.id == 'c002'), isTrue);

    final card1 = cards.firstWhere((c) => c.id == 'c001');
    expect(card1.name, 'Test Card 1');
    expect(card1.type, CardType.monster);

    // Teardown: モックをクリア
    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });
}
