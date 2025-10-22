import 'dart:math';

import 'package:flame/game.dart';

import '../../core/game_state.dart';
import '../../data/repositories/card_repository.dart';
import '../../domain/models/card_instance.dart';
import '../../domain/services/field_rule.dart';
import '../../domain/services/trigger_service.dart';
import '../components/board_component.dart';

/// ゲーム全体のライフサイクルを管理し、主要なゲームサービスへのアクセスを提供する FlameGame の実装。
///
/// このクラスは、以下の責務を持ちます:
/// - `GameState` のインスタンスを保持し、単一の状態ソースとして機能させる。
/// - ゲームの初期化処理（デッキの読み込み、シャッフル、初期手札の配布）。
/// - ユーザーのアクション（カードをプレイするなど）を受け付け、ドメインサービスに処理を委譲する。
/// - ゲームのメインループやイベント処理の起点となる。
///
/// UIの描画や更新は直接行わず、`Component` ベースのアーキテクチャに従い、
/// `BoardComponent` などの子コンポーネントに責務を委譲します。
class TCGGame extends FlameGame {
  /// ゲーム全体の共有状態。信頼できる唯一の情報源 (Single Source of Truth)。
  late final GameState gameState;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // ゲーム状態を初期化
    gameState = GameState();

    // ゲームの初期設定を行う
    await _initializeGame();

    // ゲームボードのUIコンポーネントをゲームに追加
    add(BoardComponent());
  }

  /// ゲームの初期設定（デッキのロード、シャッフル、ドロー）を行います。
  Future<void> _initializeGame() async {
    // カードリポジトリからすべてのカード定義を非同期で読み込む
    final cards = await CardRepository.loadAllCards();

    if (cards.isEmpty) {
      gameState.addToLog('Error: Failed to load cards from repository.');
      return;
    }

    // 読み込んだカード定義からカードインスタンスを生成し、デッキに追加
    for (final card in cards) {
      gameState.deck.add(CardInstance(
        card: card,
        instanceId: gameState.generateInstanceId(),
      ));
    }

    // デッキをシャッフル
    _shuffleDeck();

    // 初期手札を5枚ドロー
    for (int i = 0; i < 5; i++) {
      if (gameState.deck.isNotEmpty) {
        final card = gameState.deck.removeAt(0);
        if (card != null) {
          gameState.hand.add(card);
        }
      }
    }

    gameState.addToLog(
        'Game initialized. ${gameState.hand.count} cards in hand.');
  }

  /// デッキのカードをランダムにシャッフルします。
  void _shuffleDeck() {
    final random = Random();
    // Fisher-Yates シャッフルアルゴリズム
    for (int i = gameState.deck.count - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = gameState.deck.cards[i];
      gameState.deck.cards[i] = gameState.deck.cards[j];
      gameState.deck.cards[j] = temp;
    }
  }

  /// 指定されたインデックスの手札のカードをプレイします。
  ///
  /// このメソッドはユーザー入力の起点となり、実際のゲームロジックは
  /// `FieldRule` サービスと `TriggerService` に委譲します。
  void playCardFromHand(int handIndex) async {
    if (gameState.isGameOver) return;

    gameState.addToLog('Attempting to play card at index $handIndex...');

    // フィールドルールサービスを呼び出してカードをプレイ
    final result = FieldRule.playCardFromHand(gameState, handIndex);
    if (!result.success) {
      gameState.addToLog('Failed to play card: ${result.error}');
      // UIの更新は Component が State の変更を検知して行うため、ここでは不要
      return;
    }

    // ログを追加
    gameState.actionLog.addAll(result.logs);

    // UI更新のためのダミーコールバック。将来的にはイベントバスなどで置き換えるべき。
    final dummyUpdate = () => {};

    // トリガーサービスを呼び出して、発生したすべてのトリガーを解決
    final resolveResult =
        await TriggerService.resolveAll(gameState, dummyUpdate);
    gameState.actionLog.addAll(resolveResult.logs);

    if (!resolveResult.success) {
      gameState.addToLog('Trigger resolution failed: ${resolveResult.error}');
    }

    // ゲーム状態の変更は、リアクティブにUIコンポーネントに通知される
  }
}