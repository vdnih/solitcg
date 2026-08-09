import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/core/game_state.dart';
import 'package:solitcg/domain/services/zone_resolver.dart';

void main() {
  late GameState state;

  setUp(() {
    state = GameState();
  });

  group('ZoneResolver.byName', () {
    test('hand を渡すと state.hand を返す', () {
      expect(ZoneResolver.byName(state, 'hand'), same(state.hand));
    });

    test('deck を渡すと state.deck を返す', () {
      expect(ZoneResolver.byName(state, 'deck'), same(state.deck));
    });

    test('board を渡すと state.board を返す', () {
      expect(ZoneResolver.byName(state, 'board'), same(state.board));
    });

    test('domain を渡すと state.domain を返す', () {
      expect(ZoneResolver.byName(state, 'domain'), same(state.domain));
    });

    test('grave を渡すと state.grave を返す', () {
      expect(ZoneResolver.byName(state, 'grave'), same(state.grave));
    });

    test('extra を渡すと state.extra を返す', () {
      expect(ZoneResolver.byName(state, 'extra'), same(state.extra));
    });

    test('大文字混じりでも解決できる', () {
      expect(ZoneResolver.byName(state, 'Hand'), same(state.hand));
    });

    test('レガシー名 field は state.board を返す', () {
      expect(ZoneResolver.byName(state, 'field'), same(state.board));
    });

    test('null を渡すと null を返す', () {
      expect(ZoneResolver.byName(state, null), isNull);
    });

    test('未知のゾーン名は null を返す', () {
      expect(ZoneResolver.byName(state, 'unknown'), isNull);
    });
  });
}
