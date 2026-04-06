# Feature Registry

Feature ID（`docs/PRD.md` と対応）→ 実装コードパス・テストパス・ステータスの対応表。
機能の追加・変更を含む PR は必ずこのファイルを同時に更新すること。

## 更新プロトコル

- 機能実装開始時: ステータスを `In Progress` に変更
- 実装完了時: ステータスを `Done` に変更 ※テストパスが記入されていること
- 設計変更で既存機能に影響が出た場合: ステータスを `Modify` に変更し、備考に変更内容を記載

## ステータス凡例

| マーク | 意味 |
|---|---|
| 🟢 Done | 実装・テスト完了 |
| 🔵 Modify | 設計変更により修正中 |
| 🟡 In Progress | 実装中 |
| ⚪ Planned | 計画済み・未着手 |

---

## Phase 1 — MVP

| ID | 機能名 | ステータス | 主要実装パス | テストパス | 備考 |
|---|---|---|---|---|---|
| F-001 | コアゲームエンジン | 🟢 Done | `lib/core/game_state.dart`<br>`lib/domain/commands/`<br>`lib/domain/services/trigger_service.dart` | `test/domain/commands/draw_card_command_test.dart`<br>`test/domain/models/game_zone_test.dart` | |
| F-002 | YAML カード読み込み | 🟢 Done | `lib/data/repositories/card_repository.dart` | `test/data/card_repository_test.dart`<br>`test/data/card_asset_loading_test.dart` | |
| F-003 | Flame ボードレンダリング | 🟢 Done | `lib/presentation/game/tcg_game.dart`<br>`lib/presentation/components/board_component.dart`<br>`lib/presentation/components/card_component.dart` | (Flame コンポーネントテスト未整備) | |
| F-004 | ゾーン UI（手札/場/墓地） | 🟢 Done | `lib/presentation/components/board_component.dart` | (ウィジェットテスト未整備) | |
| F-005 | ドメインカード置換裁定 | 🟢 Done | `lib/domain/services/field_rule.dart` | `test/domain/commands/draw_card_command_test.dart` | |
| F-006 | Firebase Auth（Google ログイン） | 🟢 Done | `lib/main.dart`<br>`lib/firebase_options.dart` | (手動テストのみ) | |
| F-007 | Firestore デッキ永続化 | 🟢 Done | `lib/data/repositories/deck_repository.dart` | (手動テストのみ) | |
| F-008 | デッキビルダー画面 | 🟢 Done | `lib/ui/screens/deck_builder_screen.dart`<br>`lib/ui/screens/deck_selector_screen.dart`<br>`lib/providers/deck_provider.dart` | (ウィジェットテスト未整備) | |

---

## Phase 2 — ポスト MVP

| ID | 機能名 | ステータス | 主要実装パス | テストパス | 備考 |
|---|---|---|---|---|---|
| F-009 | パズルモード | ⚪ Planned | TBD | TBD | |
| F-010 | ランダム/シャッフルモード | ⚪ Planned | TBD | TBD | |
| F-011 | カードアニメーション | ⚪ Planned | TBD | TBD | |
| F-012 | カードプール拡充 | ⚪ Planned | `assets/cards/` | TBD | |
| F-013 | リプレイシステム | ⚪ Planned | TBD | TBD | |
