# SoliTCG - 開発ワークフローと自律実行ルール

## 1. プロジェクト概要

TCG 風ソリティアゲーム。対戦相手なしに、カード連鎖のコンボを設計・実行する体験を提供する。
詳細なビジョン・価値観は `docs/PRODUCT_VISION.md`、機能要件は `docs/PRD.md` を参照。

---

## 2. 自律実行ポリシー (Vibe Coding Policy)

### 2.1. 基本姿勢

- 途中で人間に質問や承認を求めず、Sub Agent を駆使して可能な限り自己解決すること。
- エラーが発生した場合も、ログを解析して修正ループを自律的に回すこと。
- **設計ドキュメントの変更**は必ず `docs/audit_log.md` に理由を記録すること。

### 2.2. 監査ログ (Audit Log) の絶対義務

すべての重要な意思決定は `docs/audit_log.md` に時系列で追記すること。

記録対象: アーキテクチャ判断・ファイル作成/削除・テスト失敗理由と修正内容・依存パッケージの追加

```
## YYYY-MM-DD HH:MM - [カテゴリ] タイトル
- **判断内容**: 何をしたか
- **理由**: なぜそうしたか
- **影響範囲**: どのファイルに影響するか
- **ADR**: 関連する ADR ファイル（あれば）
```

### 2.3. 2フェーズ実行モデル

- **Phase 1 (設計)**: 関連ドキュメントの読み込み → 実装計画の策定。ここで一旦停止し、人間のレビューを待つ。
- **Phase 2 (実装)**: 人間の承認後、TDD 実装 → テスト実行 → `feature_registry.md` 更新を自律実行する。
- 人間から「Phase 2 を開始して」と指示があるまで、実装コードの生成に着手しないこと。

---

## 3. 技術スタック（確定事項 - 判断不要）

### フロントエンド (Flutter)

- **言語**: Dart 3.x
- **ゲームエンジン**: Flame（最新版）
- **状態管理**: `ValueNotifier`（GameState が SSoT として保持）
- **コード生成**: `build_runner`、`freezed`、`json_serializable`

### バックエンド (Firebase)

- **認証**: Firebase Authentication（Google Sign-In）
- **DB**: Cloud Firestore（`asia-northeast1`）
- **ストレージ**: Cloud Storage for Firebase（`asia-northeast1`）
- **ホスティング**: Firebase Hosting（Web 版・CanvasKit レンダラー）

### 開発ツール

- **テスト**: `package:test`（Domain/Data）、`package:flutter_test`（Widget）、`package:mocktail`（モック）
- **リント**: `flutter_lints`
- **CI**: GitHub Actions

---

## 4. 判断に迷ったときのデフォルト方針

| 判断ポイント | デフォルト方針 |
|---|---|
| Flame コンポーネントのロジック | 持たせない。ロジックは `lib/domain/` に置く |
| 新しい op（カード効果） | `CardEffectCommand` を継承した新クラスを作成し、`OperationExecutor` に登録 |
| カードデータの変更 | `assets/cards/*.yaml` を編集。コード変更は原則不要 |
| エラーハンドリング | Domain 層は例外をスロー。Presentation 層でキャッチしてゲームログへ表示 |
| 命名規則 | Dart 公式スタイルガイドに従う（lowerCamelCase / UpperCamelCase） |
| テストの粒度 | 1テストメソッド = 1 アサーションを原則 |
| 新規パッケージの追加 | pub.dev の Like 数 500 以上、最終更新 6 ヶ月以内を目安 |
| MVP スコープ外の機能 | 実装しない。TODO コメントを残して `audit_log.md` に記録 |

---

## 5. エージェント体制

### 5.1. ロール構成

| ロール | 定義ファイル | 責務 |
|---|---|---|
| **メインエージェント** (Project Manager) | *(Claude Code 本体)* | オーケストレーション、`audit_log.md` 記録、`feature_registry.md` 管理 |
| **Architect** | `.claude/agents/architect.md` | `PRODUCT_VISION.md`・`SOFTWARE_ARCHITECTURE.md`・ADR の策定・更新 |
| **Implementer** | `.claude/agents/implementer.md` | Flutter/Flame 実装（TDD）、Firebase 連携コード |
| **QA** | `.claude/agents/qa.md` | テストシナリオ設計、テスト実行、品質レポート |

### 5.2. ファイル所有権（ネガティブリスト方式）

各エージェントが**触ってはいけないファイル**：

- **Architect**: `lib/` 配下・`test/` 配下のコード全般（設計のみ担当）。技術選択時は ADR を作成する。
- **Implementer**: `docs/PRD.md`・`docs/PRODUCT_VISION.md`・`docs/SOFTWARE_ARCHITECTURE.md`・`docs/FIREBASE_ARCHITECTURE.md`・`docs/adr/`（設計ドキュメントを書き換えない）
- **QA**: `lib/` 配下のプロダクトコード（テストコードのみ触る。プロダクトコードの修正は Implementer に依頼）

### 5.3. エージェント呼び出しの原則

- メインエージェントは、タスクの種類に応じて適切な Sub Agent に委譲する。
- Sub Agent に渡すプロンプトには「参照すべきドキュメントのパス」と「成果物の出力先」を明示する。
- Sub Agent の作業完了後、メインエージェントは成果物を確認し、問題があれば再実行を指示する。

---

## 6. ドキュメント体系

```
docs/
├── PRODUCT_VISION.md        # Mission・Vision・Values（プロダクトの憲法）
├── PRD.md                   # ビジョン・ターゲット・フェーズ別機能一覧
├── SPEC.md                  # エンジンビジネスルール仕様（カード挙動の権威）
├── adr/                     # Architecture Decision Records（なぜその設計か）
├── FIREBASE_ARCHITECTURE.md # Firebase インフラ・Firestore スキーマ設計
├── SOFTWARE_ARCHITECTURE.md # ソフトウェアアーキテクチャ設計（レイヤー・パターン）
├── TESTING_POLICY.md        # テスト方針
├── CARD_YAML_SPEC.md        # カード定義 YAML スキーマ（カード追加時の参照元）
├── GAME_RULES.md            # プレイヤー向けゲームルール（ルール変更時の参照元）
├── feature_registry.md      # 機能 ID とコード/テストパスの対応表
└── audit_log.md             # 監査ログ（全重要意思決定の記録）
```

### ドキュメントと情報源の対応

| 「何を知りたいか」 | 参照先 |
|---|---|
| なぜこのゲームか（MVV） | `docs/PRODUCT_VISION.md` |
| 何の機能があるか（概要・フェーズ） | `docs/PRD.md` |
| カードのルールがどう動くか（エンジン仕様） | `docs/SPEC.md` |
| なぜこのアーキテクチャか | `docs/adr/` |
| コードの構造・設計パターン | `docs/SOFTWARE_ARCHITECTURE.md` |
| Firebase の設計 | `docs/FIREBASE_ARCHITECTURE.md` |
| YAML カードの書き方 | `docs/CARD_YAML_SPEC.md` |
| プレイヤー向けルール | `docs/GAME_RULES.md` |
| 機能とコードパスの対応 | `docs/feature_registry.md` |
| 過去の設計判断の理由 | `docs/audit_log.md` |

---

## 7. ディレクトリ構造（実装規約）

```
lib/
├── main.dart                              # エントリポイント
├── core/
│   └── game_state.dart                   # ゲーム全状態の Single Source of Truth（ValueNotifier）
│
├── data/
│   └── repositories/
│       ├── card_repository.dart          # YAML → CardData パース
│       └── deck_repository.dart          # Firestore デッキ CRUD
│
├── domain/
│   ├── models/                           # CardData, CardInstance, GameZone 等
│   ├── services/                         # FieldRule, TriggerService, ExpressionEvaluator
│   └── commands/                         # CardEffectCommand, OperationExecutor, 各 op コマンド
│
├── presentation/
│   ├── game/
│   │   └── tcg_game.dart                # FlameGame を継承したゲーム本体
│   └── components/
│       ├── board_component.dart          # 盤面 UI の統括
│       └── card_component.dart           # 単一カードの描画
│
├── providers/
│   └── deck_provider.dart               # デッキ状態の管理
│
├── routes.dart                          # ルーティング定義
│
└── ui/
    └── screens/
        ├── main_screen.dart
        ├── game_screen.dart
        ├── deck_builder_screen.dart
        └── deck_selector_screen.dart

assets/
└── cards/
    ├── index.yaml                        # カード一覧インデックス
    └── *.yaml                            # 個別カード定義

test/
├── data/                                 # Data 層のテスト
└── domain/                              # Domain 層のテスト（最重要）
    ├── commands/
    └── models/
```

---

## 8. Git 運用ルール

- **作業ブランチ**: `claude/` プレフィックスのブランチで作業する（例: `claude/feature-name`）
- ブランチの作成・切替・マージは行わない（人間が管理する）
- commit は論理的な作業単位ごとに行う（1 機能 or 1 修正 = 1 commit）
- commit メッセージ規約:
  - `feat: デッキビルダー画面に検索機能を追加 (F-008)`
  - `test: DrawCardCommand のユニットテストを追加`
  - `docs: SPEC.md にトリガー解決ルールを追記`
  - `fix: ドメイン置換時の on_destroy 発火順序を修正`
- `main` ブランチへの push・merge は禁止（人間のみが実行する）

---

## 9. Feature Registry の維持義務

- Implementer Agent は機能の実装完了時に `docs/feature_registry.md` を更新すること：
  - ステータスを 🟢 Done に変更
  - 実装ファイルパスとテストファイルパスを記入
- Architect Agent は設計変更時に、影響を受ける既存機能のステータスを 🔵 Modify に変更し、備考に変更内容を記載すること。
- `feature_registry.md` は `PRD.md` と常に整合していること。
  PRD に存在する機能が registry に存在しない場合はエラーとする。
