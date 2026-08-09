import 'package:flame/game.dart';

import '../../core/game_state.dart';
import '../../data/repositories/card_repository.dart';
import '../../domain/models/card_data.dart';
import '../../domain/models/card_instance.dart';
import '../../domain/models/deck.dart';
import '../../domain/services/choice_resolver.dart';
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
  /// GameScreen の build() が onLoad() より先に呼ばれるため、コンストラクタ時に初期化する。
  final GameState gameState = GameState();

  /// ゲームで使用するデッキ
  final Deck? initialDeck;

  TCGGame({this.initialDeck});

  /// ゲームボードコンポーネントへの参照（外部からトグル操作などに使用）
  BoardComponent? boardComponent;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // ゲームの初期設定を行う
    await _initializeGame();

    // ゲームボードのUIコンポーネントをゲームに追加
    boardComponent = BoardComponent();
    add(boardComponent!);
  }

  /// ゲームの初期設定（デッキのロード、シャッフル、ドロー）を行います。
  Future<void> _initializeGame() async {
    if (initialDeck == null) {
      gameState.addToLog('Error: No deck specified. Please select a deck.');
      return;
    }

    // 指定されたデッキからカードを読み込む
    final List<CardData> cards = [];
    for (final cardId in initialDeck!.cardIds) {
      final card = await CardRepository.loadCard(cardId);
      if (card != null) {
        cards.add(card);
      }
    }

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

    gameState
        .addToLog('Game initialized. ${gameState.hand.count} cards in hand.');
  }

  /// デッキのカードをランダムにシャッフルします。
  void _shuffleDeck() {
    gameState.deck.shuffle();
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
    gameState.addAllToLog(result.logs);

    // UI更新のためのダミーコールバック。将来的にはイベントバスなどで置き換えるべき。
    Map<dynamic, dynamic> dummyUpdate() => {};

    // トリガーサービスを呼び出して、発生したすべてのトリガーを解決
    final resolveResult =
        await TriggerService.resolveAll(gameState, dummyUpdate);
    gameState.addAllToLog(resolveResult.logs);

    if (!resolveResult.success) {
      gameState.addToLog('Trigger resolution failed: ${resolveResult.error}');
    }

    // ゲーム状態の変更は、リアクティブにUIコンポーネントに通知される
  }

  /// プレイヤーがカード選択を確定し、ChoiceRequest を解決してトリガー解決を再開する。
  ///
  /// [selected] には ChoiceRequest.candidates の中からプレイヤーが選んだカードを渡す。
  /// 実際の選択適用ロジックは [ChoiceResolver] に委譲する。
  Future<void> resolveChoice(List<CardInstance> selected) async {
    final result = ChoiceResolver.applySelection(gameState, selected);
    gameState.addAllToLog(result.logs);

    // 選択待ちに戻っていなければ、トリガーキューの残りを再開する
    if (!result.awaitingChoice && gameState.choiceRequest.value == null) {
      Map<dynamic, dynamic> dummyUpdate() => {};
      final resolveResult = await TriggerService.resolveAll(gameState, dummyUpdate);
      gameState.addAllToLog(resolveResult.logs);
    }
  }

  /// 指定されたフィールドのカードの効果を発動させます。
  ///
  /// このメソッドはユーザー入力の起点となり、実際のゲームロジックは
  /// `TriggerService` に委譲します。
  void activateCardOnBoard(CardInstance card) async {
    if (gameState.isGameOver) return;

    // `activated` 効果を持つアビリティを探す
    final activatedAbilities = card.card.abilities
        .where((ability) => ability.when == TriggerWhen.activated)
        .toList();

    if (activatedAbilities.isEmpty) {
      gameState.addToLog('${card.card.name} には activated 能力がありません。');
      return;
    }

    // MVPでは最初に見つかった効果のみを発動
    final abilityToActivate = activatedAbilities.first;

    // 1ターン1度制限チェック（oncePerTurn が true の場合のみ）
    if (abilityToActivate.oncePerTurn &&
        gameState.activatedThisTurn.contains(card.instanceId)) {
      gameState.addToLog('${card.card.name} はすでにこのターン発動済みです。');
      return;
    }

    gameState.addToLog('${card.card.name} を起動...');

    // 使用済みとして記録（oncePerTurn が true の場合のみ）
    if (abilityToActivate.oncePerTurn) {
      gameState.activatedThisTurn.add(card.instanceId);
    }

    // トリガーサービスにアビリティをエンキュー
    TriggerService.enqueueAbility(gameState, card, abilityToActivate);

    // UI更新のためのダミーコールバック
    Map<dynamic, dynamic> dummyUpdate() => {};

    // トリガーサービスを呼び出して、発生したすべてのトリガーを解決
    final resolveResult =
        await TriggerService.resolveAll(gameState, dummyUpdate);
    gameState.addAllToLog(resolveResult.logs);

    if (!resolveResult.success) {
      gameState.addToLog('トリガー解決に失敗しました: ${resolveResult.error}');
    }
  }
}
