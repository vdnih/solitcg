import 'package:flutter/material.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/deck_builder_screen.dart';
import 'ui/screens/deck_selector_screen.dart';
import 'ui/screens/game_screen.dart';

/// ルート定義クラス
class AppRoutes {
  static const String home = '/';
  static const String deckBuilder = '/deck_builder';
  static const String deckSelector = '/deck_selector';
  static const String game = '/game';
  
  /// ルート設定を返す
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const MainScreen(),
      deckBuilder: (context) => const DeckBuilderScreen(),
      deckSelector: (context) => const DeckSelectorScreen(),
      game: (context) => const GameScreen(),
    };
  }
  
  /// 名前付きルートへ遷移
  static void navigateTo(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }
}