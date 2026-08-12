# SoliTCG - 開発ガイド

TCG 風ソリティアゲーム。対戦相手なしに、カード連鎖のコンボを設計・実行する体験を提供する。
詳細なビジョン・価値観は `docs/PRODUCT_VISION.md`、機能要件は `docs/PRD.md` を参照。

## コマンド

```bash
flutter pub get                      # 依存解決
flutter analyze                      # 静的解析（0件が目標）
flutter test                         # Domain/Data のユニットテスト
flutter build web --release          # Web ビルド
flutter run -d chrome                # ローカル実行
```

## ドキュメント

| 知りたいこと | 参照先 |
|---|---|
| なぜこのゲームか（MVV） | `docs/PRODUCT_VISION.md` |
| 機能一覧・実装状況 | `docs/PRD.md` |
| カードのルールがどう動くか（エンジン仕様） | `docs/SPEC.md` |
| なぜこのアーキテクチャか | `docs/adr/` |
| コードの構造・設計パターン | `docs/SOFTWARE_ARCHITECTURE.md` |
| Firebase の設計・接続状況 | `docs/FIREBASE_ARCHITECTURE.md` |
| YAML カードの書き方・命名規則 | `docs/CARD_YAML_SPEC.md` |
| プレイヤー向けルール | `docs/GAME_RULES.md` |
| 過去の設計判断の理由 | `docs/audit_log.md`（任意記録、必須ではない） |

## 技術スタック上の注意点

- **Firebase**: `firebase_auth` / `google_sign_in` / `cloud_firestore` / `firebase_storage` は依存関係として宣言されているが **`lib/` からは未接続**。デッキ永続化は `DeckRepository` による localStorage（Web）/ ローカルファイル（ネイティブ）で行っている。Firestore を使うコードを書かないこと。
- **状態管理**: `GameState`（`lib/core/game_state.dart`）が SSoT。カードゾーン（手札・場等）は `ValueNotifier` 化されていない。Flutter 側は個別の `ValueNotifier`、Flame 側は `BoardComponent.update()` の毎フレームポーリング差分で反映している（全体がリアクティブではないので、新規UIが自動更新されると思わないこと）。
- `freezed` / `json_serializable` / `build_runner` / `mocktail` は依存関係になく未使用。

## 判断に迷ったときのデフォルト方針

| 判断ポイント | デフォルト方針 |
|---|---|
| Flame コンポーネントのロジック | 持たせない。ロジックは `lib/domain/` または `TCGGame` に置く |
| 新しい op（カード効果） | `OperationExecutor` に静的メソッドとして追加し `executeOperation` の switch に登録（MVP は `CardEffectCommand` 継承ではなく静的ディスパッチが実態。詳細は `docs/adr/002-command-pattern.md`） |
| カードデータの変更 | `assets/cards/*.yaml` を編集。コード変更は原則不要。命名規則は `docs/CARD_YAML_SPEC.md` |
| エラーハンドリング | Domain 層は例外をスロー。Presentation 層でキャッチしてゲームログへ表示 |
| MVP スコープ外の機能 | 実装しない |

## Git 運用ルール

- 作業ブランチ: `claude/` プレフィックス（例: `claude/feature-name`）
- commit は論理的な作業単位ごとに行う（1 機能 or 1 修正 = 1 commit）
- commit メッセージ規約:
  - `feat: デッキビルダー画面に検索機能を追加`
  - `test: DrawCardCommand のユニットテストを追加`
  - `docs: SPEC.md にトリガー解決ルールを追記`
  - `fix: ドメイン置換時の on_destroy 発火順序を修正`
