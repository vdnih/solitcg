# SoliTCG プロダクト要件定義書 (PRD)

**Version**: 1.2
**Last Updated**: 2026-09-06
**Owner**: Architect Agent

## 1. プロダクト概要

TCG 風ソリティアゲーム。対戦相手なしに、カード連鎖のコンボを設計・実行する体験を提供する。
Flutter/Flame で開発し、Web ブラウザ上で即座にプレイできることを最優先とする。

**コアコンセプト**: 「YAML で定義されたカードを組み合わせ、コンボ連鎖を決める。相手も待ち時間も不要。」

詳細なビジョン・価値観は `docs/PRODUCT_VISION.md` を参照。

## 2. ターゲットユーザー

- カードゲーム経験があり、コンボ・シナジーを考えるのが好きなプレイヤー
- ブラウザだけで手軽に遊びたいプレイヤー
- 自作カードを YAML で定義して試したいゲームデザイン興味層（将来）

## 3. 機能一覧

各機能の詳細仕様は `docs/SPEC.md` を参照。ビジネスルールの唯一の参照元は `docs/GAME_RULES.md`。

### Phase 1 — MVP（実装済み）

各機能の実装パス・テストパスは以下の通り。ステータスが 🟡 の項目は、依存パッケージは
`pubspec.yaml` に宣言されているが `lib/` からは未接続であることを示す。

| ID | 機能名 | 状態 | 実装パス | テストパス |
|---|---|---|---|---|
| F-001 | コアゲームエンジン | 🟢 | `lib/core/game_state.dart`<br>`lib/domain/commands/`<br>`lib/domain/services/trigger_service.dart` | `test/domain/commands/`<br>`test/domain/models/` |
| F-002 | YAML カード読み込み | 🟢 | `lib/data/repositories/card_repository.dart` | `test/data/card_repository_test.dart`<br>`test/data/card_asset_loading_test.dart` |
| F-003 | Flame ボードレンダリング | 🟢 | `lib/presentation/game/tcg_game.dart`<br>`lib/presentation/components/` | `test/presentation/`（BoardLayout/BoardScrollController のみ。Flame コンポーネント自体のテストは未整備） |
| F-004 | ゾーン UI（手札/場/墓地） | 🟢 | `lib/presentation/components/board_component.dart` | （ウィジェットテスト未整備） |
| F-005 | ドメインカード置換裁定 | 🟢 | `lib/domain/services/field_rule.dart` | `test/domain/services/` |
| F-006 | Firebase Auth（Google ログイン） | 🟡 未接続 | `lib/firebase_options.dart`（設定のみ） | — |
| F-007 | デッキ永続化 | 🟢 ※ | `lib/data/repositories/deck_repository.dart` | （手動テストのみ） |
| F-008 | デッキビルダー画面 | 🟢 | `lib/ui/screens/deck_builder_screen.dart`<br>`lib/providers/deck_provider.dart` | （ウィジェットテスト未整備） |

> ※ F-007 は当初 Firestore 連携を想定していたが、実際の永続化は
> `DeckRepository` による localStorage（Web）/ ローカルファイル（ネイティブ）で行っている。
> `cloud_firestore` パッケージは宣言されているが未接続。

### Phase 2 — ポスト MVP（計画中）

| ID | 機能名 | 状態 | 概要 |
|---|---|---|---|
| F-009 | パズルモード | ⚪ | 固定初期状態で「詰めソリティア」を楽しむモード |
| F-010 | ランダム/シャッフルモード | ⚪ | デッキをシャッフルして N 回試行し成功率を表示 |
| F-011 | カードアニメーション | ⚪ | プレイ・破壊・ドローの視覚演出 |
| F-012 | カードプール拡充 | 🟡 | 現在20種類。`docs/adr/006-engine-schema-reconciliation.md` によりカードタイプを4種に統合したが、既存20枚はいずれも対象外タイプを使っておらず影響なし。継続拡充・既存データの検証は後続 Issue（D-1〜D-5, V-1）で対応 |
| F-013 | リプレイシステム | ⚪ | 入力ログの保存と再生 |
| F-014 | カード画像 | ⚪ | `assets/images/cards/` は `.gitkeep` のみで未着手。現状は全カードがグラデーション矩形で代替表示される |

### Phase 3 — 将来構想（スコープ外）

- モバイル（iOS/Android）パッケージング
- デッキ共有リンク
- パズルランキング・リーダーボード
- カードエディタ（ノーコード YAML 生成 UI）

## 4. 非機能要件

| カテゴリ | 要件 |
|---|---|
| パフォーマンス | 一般的なコンボのトリガー解決 < 100ms |
| Web ターゲット | CanvasKit レンダラー。Chrome / Firefox / Safari で動作 |
| オフラインプレイ | カードデータ読み込み後はネットワーク不要でプレイ可能 |
| テスト容易性 | Domain レイヤーのカバレッジ >= 80%（純粋 Dart テスト） |
| ビルド | `flutter build web --web-renderer canvaskit` を標準コマンドとする |

## 5. デザイン方針

- カード表示：シンプルなテキスト+枠線（MVP）。演出は Phase 2 以降
- ゲームログ：効果解決の詳細をテキストで表示し、何が起きたか常に確認できる
- 色彩：モンスター / スペル / アーティファクト / ドメインで視覚的に区別

## 変更履歴

| バージョン | 日付 | 変更内容 |
|---|---|---|
| 1.2 | 2026-09-06 | `docs/adr/006-engine-schema-reconciliation.md` / `docs/pdr/PDR-001-...md` の裁定を受け、F-012 のステータスと注記を更新 |
| 1.1 | 2026-08-09 | `feature_registry.md` を統合。F-006/F-007 の Firebase 接続状況を実態に修正 |
| 1.0 | 2026-04-06 | 初版作成（ドキュメント体系整備に伴い CLAUDE.md から分離） |
