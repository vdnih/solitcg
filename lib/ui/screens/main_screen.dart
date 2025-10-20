import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routes.dart';

/// メインメニュー画面
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SolitCG'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ソリティアカードゲーム',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            
            // ゲーム開始ボタン
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              onPressed: () {
                AppRoutes.navigateTo(context, AppRoutes.game);
              },
              child: const Text('ゲームを開始', style: TextStyle(fontSize: 18)),
            ),
            
            const SizedBox(height: 20),
            
            // デッキビルダーボタン
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              onPressed: () {
                AppRoutes.navigateTo(context, AppRoutes.deckSelector);
              },
              child: const Text('デッキビルダー', style: TextStyle(fontSize: 18)),
            ),
            
            const SizedBox(height: 20),
            
            // ルール確認ボタン
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              onPressed: () {
                // TODO: ルール画面への遷移
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ルール画面は実装中です')),
                );
              },
              child: const Text('ルールを確認', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}