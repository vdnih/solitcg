import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../presentation/game/tcg_game.dart';

/// ゲームプレイ画面
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // TODO: ヘルプ画面表示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ヘルプ機能は実装中です')),
              );
            },
          ),
        ],
      ),
      body: GameWidget(
        game: TCGGame(),
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, error) => Center(
          child: Text(
            'エラーが発生しました: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        overlayBuilderMap: {
          'pause': (context, TCGGame game) => Center(
            child: Container(
              color: Colors.black54,
              child: const Text(
                '一時停止中',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
        },
      ),
    );
  }
}
