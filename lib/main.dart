import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'game/tcg_game.dart';

void main() {
  runApp(const SolitaireApp());
}

class SolitaireApp extends StatelessWidget {
  const SolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solitaire TCG',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: GameWidget<TCGGame>.controlled(
        gameFactory: TCGGame.new,
      ),
    );
  }
}