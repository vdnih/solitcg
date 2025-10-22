# 2Dカードゲーム テスト方針ドキュメント

| バージョン | 日付 | 作成者 |
| :--- | :--- | :--- |
| 1.0 | 2025/10/22 | (あなたの名前) |

## 1\. 概要

### 1.1. 目的

本ドキュメントは、「2Dカードゲーム アーキテクチャ方針書 (v1.3)」に基づき、プロジェクトの品質を担保するためのテスト方針を定義する。

アーキテクチャの強みである\*\*「関心事の分離」\*\*を最大限に活かし、テストピラミッドに従った効率的かつ網羅的なテスト戦略を実施することで、以下の目標を達成する。

  * 複雑なカードロジックの動作保証
  * 機能追加やリファクタリングによるデグレード（意図しない不具合）の防止
  * 保守性と拡張性の高いコードベースの維持

### 1.2. 参照ドキュメント

  * **2Dカードゲーム アーキテクチャ方針書 (v1.3)**

### 1.3. テストの基本方針 (テストピラミッド)

本プロジェクトは、テストピラミッドの考え方を厳格に適用する。
**「Domainレイヤー」のロジックが分離されているため、テストの大部分（約70-80%）を高速かつ安定なL1: 単体テスト**でカバーする。

[Image of the software testing pyramid]

  * **L1: 単体テスト (Unit Tests):** 最も多く書く。ロジックの正しさを検証。
  * **L2: ウィジェット/コンポーネントテスト (Widget/Component Tests):** 中間量。UIと状態の「連携」を検証。
  * **L3: E2Eテスト (End-to-End Tests):** 最小限。主要なユーザーシナリオを検証。

## 2\. テストのレベルと対象範囲

アーキテクチャの各レイヤーに対し、以下のテストレベルを割り当てる。

| レベル | レイヤー | テスト対象 | 目的 |
| :--- | :--- | :--- | :--- |
| **L1** | **Domain** | `commands/` (Command)<br>`services/` (Service)<br>`models/` (Model) | **(最重要)** カード効果、ルール判定、トリガーなどの全ゲームロジックの動作検証。 |
| **L1** | **Data** | `repositories/` (Repository) | 外部I/F（Firebase）のモック化による、データマッピングと通信ロジックの検証。 |
| **L2** | **Presentation** | `components/` (Flame Component)<br>Flutter `Widget` | **(重要)** `GameState`の変更に対する、UIのリアクティブな更新の検証。ビジュアルリグレッションの防止（ゴールデンテスト）。 |
| **L3** | **全レイヤー** | アプリケーション全体 | Firebaseとの実結合を含めた、クリティカルパス（アプリ起動〜対戦勝利など）の動作保証。 |

-----

## 3\. レイヤー別テスト戦略（テストコード作成の指針）

Flutterのテストコード作成時は、以下の戦略に従うこと。

### 3.1. L1: Domainレイヤー (純粋なDartテスト)

  * **方針:**
    アーキテクチャの核である`GameState` (SSoT) と `Command` (ロジック) の分離を活かし、Flutter/Flameを**一切起動せずに**ロジックをテストする。
  * **使用パッケージ:** `package:test`
  * **テストコードの書き方:**
    1.  **Arrange (準備):** テスト対象の`GameState`インスタンスを準備し、テストに必要な初期状態（デッキの枚数、手札、ライフなど）を設定する。
    2.  **Act (実行):** テスト対象の`Command` (例: `DrawCardCommand`) や `Service` (例: `FieldRule`) のメソッドを実行し、引数として準備した`GameState`を渡す。
    3.  **Assert (検証):** `expect`を使い、`GameState`のプロパティ（`hand.value`, `deck.value`など）が期待通りに変化したことを検証する。

<!-- end list -->

```dart
// test/domain/commands/draw_card_command_test.dart
test('デッキが2枚の時にDrawCardCommand(1)を実行すると、手札が1枚増え、デッキが1枚になる', () {
  // 1. Arrange
  final gameState = GameState();
  gameState.deck.value = [CardInstance('A'), CardInstance('B')];
  gameState.hand.value = [];
  final command = DrawCardCommand(count: 1);

  // 2. Act
  command.execute(gameState);

  // 3. Assert
  expect(gameState.hand.value.length, 1);
  expect(gameState.deck.value.length, 1);
});
```

### 3.2. L1: Dataレイヤー (モックを使用したテスト)

  * **方針:**
    `Repository`クラスが依存する外部SDK（`FirebaseFirestore`など）をモック（偽物）に差し替え、ネットワーク通信を発生させずにテストする。
  * **使用パッケージ:** `package:test`, `package:mocktail`
  * **テストコードの書き方:**
    1.  **Arrange (準備):** `Mocktail`を使い、`FirebaseFirestore`などのモッククラスを作成する。`when(...)`を使い、モックが呼ばれた際のダミーの戻り値（例: Firestoreの`Map`データ）を定義する。
    2.  **Act (実行):** モックを注入して`CardRepository`をインスタンス化し、テスト対象のメソッド（例: `getAllCards`）を実行する。
    3.  **Assert (検証):** 戻り値が、`Repository`によって正しく`Card`モデルに変換されていることを検証する。

### 3.3. L2: Presentationレイヤー (ウィジェット/コンポーネントテスト)

  * **方針:**
    **ロジックはテストしない**（L1で保証済み）。「`GameState`が変更されたら、`Component`が正しく反応するか」という**リアクティブな振る舞い**のみをテストする。

  * **使用パッケージ:** `package:flutter_test`, `package:flame_test`

  * **テストコードの書き方 (リアクティブテスト):**

    1.  **Arrange (準備):** `flame_test`の`testWithGame`ヘルパーを使い、`TCGGame`（と、それが持つ`GameState`）を準備する。
    2.  **Act (実行):** `game.gameState`のプロパティ（例: `addCardToHand()`）を直接操作し、状態を変更する。`await game.ready()`でUIの更新を待つ。
    3.  **Assert (検証):** `game.children.whereType<CardComponent>()`などを使い、`BoardComponent`の子コンポーネントの数や状態が、`GameState`の変更に追従して正しく変化したことを検証する。

  * **テストコードの書き方 (ゴールデンテスト):**

      * **方針:** `GameState`から特定の状態（例: ライフが少ない、手札が多い）をUIに描画させ、そのスクリーンショットを「正解画像」として保存・比較する。
      * **実施:** `await expectLater(game, matchesGoldenFile(...))` を使用し、意図しない見た目の変化を自動検出する。

## 4\. テスト環境と自動化

### 4.1. 使用ツール一覧

| 用途 | パッケージ |
| :--- | :--- |
| L1 (Domain, Data) | `package:test` |
| L1 (モック化) | `package:mocktail` |
| L2 (Flutter Widget) | `package:flutter_test` |
| L2 (Flame Component) | `package:flame_test` |
| L3 (E2E) | `package:integration_test` |

### 4.2. 実行戦略

  * **ローカル開発時:**
      * 開発者は、ロジック（`Domain`）やUI（`Presentation`）を変更した場合、対応するL1またはL2テストを作成し、`flutter test`コマンドで実行・成功を確認する。
  * **CI（継続的インテグレーション）:**
      * **Pull Request作成/更新時:** L1およびL2の全テスト (`flutter test`) を自動実行する。テストが失敗したPull Requestのマージを禁止する。
      * **`main`ブランチへのマージ時:** L1, L2テストに加え、L3 (E2E) テスト (`integration_test`) を定期的に（またはマージ時に）実行し、本番環境相当での動作を保証する。