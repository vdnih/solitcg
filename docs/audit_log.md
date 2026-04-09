# アーキテクチャ監査ログ

重要な設計・アーキテクチャ判断の時系列記録。
詳細な根拠は各 ADR（`docs/adr/`）を参照。

## 2026-04-09 14:30 - [バグ修正] 連続選択効果で2つ目以降の effect が消失する問題を修正

- **判断内容**: `ChoiceRequest` に `pendingEffects` フィールドを追加し、選択中断時に残り effect を保持するよう変更。`_resolveTrigger` でインデックスループに変更して残り effect を格納、`resolveChoice` で pendingEffects を順次実行し連続選択に対応
- **理由**: `artifact_crystal_recycle.yaml` のように discard→move の2段階選択を持つカードで、1つ目の選択後に2つ目の effect が失われていた（トリガー dequeue 後の残り effect が保存されていなかった）
- **影響範囲**: `lib/domain/models/choice_request.dart`、`lib/domain/services/trigger_service.dart`、`lib/presentation/game/tcg_game.dart`、`test/domain/services/trigger_service_test.dart`
- **ADR**: なし（実装バグ修正のため）

## 2026-04-09 14:00 - [バグ修正] selection: choose 効果でChoiceUIが表示されない問題を修正

- **判断内容**: `TriggerService._resolveTrigger` に `awaitingChoice` チェックを追加し、`OperationExecutor` の discard/move/destroy で `selection: choose` パラメータを読むよう条件を変更した
- **理由**: ①`_resolveTrigger` が `executeOperation` の `pending` 結果を無視してループを継続していた。② `selection: choose` のみ（filter なし）の効果で ChoiceUI が出ないバグがあった（条件が `filter.isNotEmpty` のみだったため）
- **影響範囲**: `lib/domain/services/trigger_service.dart`、`lib/domain/commands/operation_executor.dart`、`test/domain/commands/operation_executor_test.dart`、`test/domain/services/trigger_service_test.dart`
- **ADR**: なし（実装バグ修正のため）

## 記録フォーマット

```
## YYYY-MM-DD HH:MM - [カテゴリ] タイトル
- **判断内容**: 何をしたか
- **理由**: なぜそうしたか
- **影響範囲**: どのファイルに影響するか
- **ADR**: 関連する ADR ファイル（あれば）
```

記録対象: アーキテクチャ判断・ファイル作成/削除・テスト失敗理由と修正内容・依存パッケージの追加

---

## 2026-04-09 - [Feature] 水力発電所カード追加（汎用カウンター + on_spell_played トリガー）

- **判断内容**:
  - `TriggerWhen.onSpellPlayed` を追加し、domain カードが spell/arcane のプレイを購読できるようにした
  - `OperationExecutor` に `add_counter` / `remove_counter` op を追加。`CardInstance.metadata` に per-card カウンターを格納する
  - `OperationExecutor.executeOperation` に `{CardInstance? source}` パラメータを追加し、トリガー発生元カードを effect 実行時に参照できるようにした
  - `ExpressionEvaluator` に `{CardInstance? self}` パラメータを追加し、`self.counter('key')` 式で発生元カードのメタデータを参照できるようにした
  - `TriggerService._resolveTrigger` で `trigger.source` を `executeOperation` と `evaluate` に伝播するよう変更
  - `FieldRule.playCard` の spell/arcane ブランチで、domain カードの `onSpellPlayed` アビリティをキューに追加する処理を実装
  - カード定義 `assets/cards/dmn_suiryoku_001.yaml` を新規作成（2アビリティ FIFO アプローチ: spell play → add_counter、条件付き remove_counter + draw）
- **理由**:
  - 「spell が発動されるたびにカウンターを積み、4つで draw」という効果を既存エンジンで表現するために、per-card カウンターシステムと spell 監視トリガーが必要だった
  - 2アビリティアプローチ（add_counter と条件付き draw を別アビリティに分割）を採用した理由：FIFO 解決順序により ability1（add_counter）が先に解決され、ability2 の pre 条件（`>= 4`）が正しく評価されることが保証されるため
- **影響範囲**:
  - `lib/domain/models/card_data.dart`（enum 拡張）
  - `lib/data/repositories/card_repository.dart`（parse 追加）
  - `lib/domain/services/expression_evaluator.dart`（self パラメータ追加）
  - `lib/domain/commands/operation_executor.dart`（source パラメータ + 新 op）
  - `lib/domain/services/trigger_service.dart`（source 伝播 + enum 対応）
  - `lib/domain/services/field_rule.dart`（onSpellPlayed 通知）
  - `assets/cards/dmn_suiryoku_001.yaml`（新規）
  - `assets/cards/index.yaml`（エントリ追加）
- **ADR**: なし（既存アーキテクチャの自然な拡張）

## 2026-04-08 - [Feature] タグシステム拡充 + 汎用カード選択 UI の実装

- **判断内容**:
  - `discard` / `move` / `destroy` op に `filter` パラメータを追加し、タグ・タイプ・名前でカードを絞り込めるようにした
  - `ChoiceRequest` モデルを再設計（`candidates: List<CardInstance>`, `sourceZone`, `targetZone` を追加。`pendingEffects` は削除）
  - `GameResult` に `awaitingChoice: bool` フラグと `GameResult.pending()` ファクトリを追加
  - `TriggerService.resolveAll()` に `awaitingChoice` 検出・一時停止ロジックを追加
  - `TCGGame.resolveChoice()` を追加し、選択後のトリガー再開を実装
  - `CardDetailPanel` にタグ Chip 表示を追加
  - `ChoiceOverlay` ウィジェットを新規作成（候補カードグリッド + 確定ボタン）
  - `GameScreen` に `ChoiceOverlay` を `ValueListenableBuilder` で接続
- **理由**: filter なしの op は先頭から自動選択（従来動作）、filter あり + 複数候補の場合のみプレイヤーに選択を委ねる設計にすることで後方互換性を維持しつつ UX を改善
- **影響範囲**:
  - `lib/domain/models/choice_request.dart` （再設計）
  - `lib/domain/models/game_result.dart` （フラグ追加）
  - `lib/domain/commands/operation_executor.dart` （filter 対応）
  - `lib/domain/services/trigger_service.dart` （一時停止）
  - `lib/presentation/game/tcg_game.dart` （resolveChoice 追加）
  - `lib/ui/widgets/card_detail_panel.dart` （タグ表示）
  - `lib/ui/widgets/choice_overlay.dart` （新規）
  - `lib/ui/screens/game_screen.dart` （接続）
  - `test/domain/commands/operation_executor_test.dart` （テスト15件追加）
  - `docs/CARD_YAML_SPEC.md` / `docs/SPEC.md` （ドキュメント更新）

---

## 2025-10-22 00:00 - [Architecture] 3層アーキテクチャ採用

- **判断内容**: Presentation / Domain / Data の 3 層構造を採用
- **理由**: 複雑化するカード効果ロジックを Domain に閉じ込め、Flame コンポーネントとゲームロジックを分離するため。テスト容易性と拡張性の確保。
- **影響範囲**: `lib/` 全体のディレクトリ構造
- **ADR**: `docs/adr/001-layered-architecture.md`

## 2025-10-22 00:00 - [Architecture] コマンドパターン採用

- **判断内容**: カード効果を `CardEffectCommand` サブクラスとしてオブジェクト化
- **理由**: 効果ロジックを独立してテスト可能にし、YAML の `op` 文字列から動的に生成できるようにするため
- **影響範囲**: `lib/domain/commands/`
- **ADR**: `docs/adr/002-command-pattern.md`

## 2025-10-22 00:00 - [Architecture] Firebase サーバーレス構成採用

- **判断内容**: Cloud Functions を使わず、クライアントサイドで完結するサーバーレス構成
- **理由**: 個人開発スケール・ソリティア型ゲームでは厳密なサーバーサイドバリデーションのコストが見合わない。ゲームループのパフォーマンスをネットワーク遅延から守るため。
- **影響範囲**: `docs/FIREBASE_ARCHITECTURE.md`、`lib/data/repositories/`
- **ADR**: `docs/adr/003-firebase-serverless.md`

## 2025-10-22 00:00 - [Architecture] FIFO トリガーキュー採用

- **判断内容**: 誘発処理を FIFO キューで自動解決。プレイヤーはキュー順序を操作できない
- **理由**: チェーンによる複雑な選択を排除し、ソリティア形式の「自動解決」という設計思想を実装するため
- **影響範囲**: `lib/domain/services/trigger_service.dart`
- **ADR**: `docs/adr/004-fifo-trigger-queue.md`

## 2025-10-22 00:00 - [Architecture] YAML 駆動カードデータ採用

- **判断内容**: カードデータを YAML ファイルで定義し、エンジンが実行時に読み込む方式
- **理由**: 新カードの追加をコード変更なしに実現し、デザイン変更とエンジン実装を分離するため
- **影響範囲**: `assets/cards/`、`lib/data/repositories/card_repository.dart`
- **ADR**: `docs/adr/005-yaml-card-data.md`

## 2026-04-06 12:00 - [Docs] ゲームルール総点検・ドキュメント簡素化

- **判断内容**: GAME_RULES.md / SPEC.md / CARD_YAML_SPEC.md の不整合を一括解消し、MVP ルールセットを簡素化した
- **理由**: 継ぎ足しメンテナンスにより3ドキュメント間で `when` 一覧・`banish` ゾーンの扱い・`op` 定義が食い違っていたため。また、`static` 効果など実装負荷の高い機能をスコープ外と明確化することで、実装がシンプルになるよう設計を見直した
- **影響範囲**: `docs/GAME_RULES.md`（v0.5.0）、`docs/SPEC.md`（v1.1）、`docs/CARD_YAML_SPEC.md`（v0.6.0）、`assets/cards/`（カード YAML 修正・削除）
- **変更サマリー**:
  - `when` を4種に統一（`on_play` / `on_destroy` / `on_discard` / `activated`）。`on_enter` / `static` / `on_draw` / `on_domain_set` は MVP スコープ外と明記
  - `banish` ゾーンを MVP スコープ外として3ドキュメントから削除
  - `priority` フィールドを廃止。同時トリガーはプレイヤーが投入順を選択する方式に変更
  - `op: win`（無条件勝利）を仕様に追加
  - `activated` 能力の1ターン1度制限をエンジン強制と明記
  - `stats.atk` / `stats.def` を optional（効果参照用）に変更。`hp` のみ必須
  - `domain_library.yaml` を削除（`static` + `modify_draw` を使用しており再設計不能）
  - `van001.yaml` のフォーマット不正（リスト形式）を修正
  - `spl_haku` / `spl_hatsu` / `spl_chun` のタイポ（`chose` → `choose`）と `target` の矛盾を修正
  - `activated_artifact.yaml` を日本語化
- **ADR**: なし

## 2026-04-06 00:00 - [Docs] ドキュメント体系整備

- **判断内容**: `my_career_app` / `travel_log_app` に倣いドキュメント構成を整備。PRODUCT_VISION.md・PRD.md・SPEC.md・feature_registry.md・audit_log.md・adr/ を新設。CLAUDE.md を全面改訂。
- **理由**: AI エージェントが設計意図を正確に把握し、一貫した開発スタイルを維持するため
- **影響範囲**: `docs/` 全体、`CLAUDE.md`、`README.md`
- **ADR**: なし（ドキュメント整備のため）

## 2026-04-08 00:00 - [UI] カード画像・選択システム・ビジュアルポリッシュ

- **判断内容**: (1) CardData に `String? image` フィールドを追加し YAML から読み込む。(2) 2タップ選択モデルを実装（1回目=選択+詳細パネル表示、2回目=プレイ/発動）。(3) 全体的な UI ポリッシュ（グラデーションカード・ゾーン背景・HUD・ログパネル）。
- **理由**: カードビジュアルの貧弱さとタップ即プレイの UX 問題を解消し、TCG らしいカッコいい画面を実現するため。
- **影響範囲**: `lib/domain/models/card_data.dart`, `lib/domain/models/card_selection_state.dart`（新規）, `lib/core/game_state.dart`, `lib/presentation/components/card_component.dart`, `lib/presentation/components/board_component.dart`, `lib/ui/screens/game_screen.dart`, `lib/ui/theme/game_theme.dart`（新規）, `lib/ui/widgets/card_detail_panel.dart`（新規）, `pubspec.yaml`
- **ADR**: なし（UI 改善のため）

## 2026-04-08 - [Feature] activated 能力の発動制限をカードごとに設定可能に変更

- **判断内容**: `Ability` クラスに `oncePerTurn` フィールド（bool, デフォルト `true`）を追加。YAML の `once_per_turn` フィールドで制御。エンジンの1ターン1度強制を `oncePerTurn: true` のカードのみに限定。
- **理由**: カード効果として「1ターン1度」だけでなく「コストが払えれば何度でも」発動できる activated 能力を設計できるよう拡張するため。
- **影響範囲**: `lib/domain/models/card_data.dart`, `lib/data/repositories/card_repository.dart`, `lib/presentation/game/tcg_game.dart`, `docs/SPEC.md`, `docs/CARD_YAML_SPEC.md`, `test/data/card_repository_test.dart`, `test/domain/services/activate_once_per_turn_test.dart`（新規）
- **ADR**: なし

---

## 2026-04-09 - [機能追加] search op に random パラメータを追加 + 宝石の採掘カード実装

- **判断内容**: `search` op に `random: bool`（デフォルト `false`）パラメータを追加。`true` の場合、フィルタ一致カードをシャッフルしてから `max` 枚選択することでランダムサーチを実現。カード「宝石の採掘」（`spl_mining_gem_001`）を新規作成。
- **理由**: 「宝石の採掘」の「ランダムに1枚」という挙動を実現するため。既存の `search` op はデッキ先頭から取るため非ランダム。新たな op は作らず既存 op の拡張で対応（最小変更の原則）。
- **影響範囲**: `lib/domain/commands/operation_executor.dart`, `assets/cards/spl_mining_gem.yaml`（新規）, `assets/cards/index.yaml`, `test/domain/commands/operation_executor_test.dart`
- **ADR**: なし
