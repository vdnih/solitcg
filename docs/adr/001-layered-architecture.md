# ADR-001: 3層レイヤードアーキテクチャの採用

## Status
Accepted

## Date
2025-10-22

## Context

Flutter/Flame でカードゲームを構築する際、ゲームのルール・ロジック・UI・データアクセスが一体化すると、カード効果の追加・変更・テストが困難になる。特に Flame コンポーネントにゲームロジックが混在すると、ロジックの単体テストが不可能になる。

## Decision

コードベースを以下の3層に分割する：

- **Presentation 層** (`lib/presentation/`): Flame コンポーネント・Flutter Widget。見た目とユーザー入力受付のみ。
- **Domain 層** (`lib/domain/`): ゲームルール・カード効果・状態管理。純粋な Dart クラス。
- **Data 層** (`lib/data/`): YAML 読み込み・Firebase 通信。Repository パターンで実装。

`lib/core/game_state.dart` が唯一の情報源（Single Source of Truth）として機能し、全ゾーン・ライフ等の状態を保持する。

## Consequences

**Positive:**
- Domain 層のロジックは Flame/Flutter を起動せずに `package:test` だけでテスト可能。
- 新しいカード効果の追加は Domain 層の変更のみで完結し、UI に影響しない。
- 各層を独立して変更・テストできるため、技術的負債の蓄積を防ぎやすい。

**Negative:**
- 小さな機能でも3つのファイルに跨る可能性がある。
- Flame の慣習（コンポーネントに状態を持たせる）と一部相反するため、意識的な境界維持が必要。

## References

- `lib/core/game_state.dart`
- `lib/domain/`
- `lib/presentation/`
- `docs/SOFTWARE_ARCHITECTURE.md` §2〜§4
