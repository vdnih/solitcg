# ADR-002: コマンドパターンによるカード効果の実装

## Status
Accepted

## Date
2025-10-22

## Context

カードゲームの効果は多様であり（draw、destroy、search、modify_stat 等）、かつ YAML の `op` フィールドで動的に指定される。
switch/if チェーンをゲームループに直書きすると、新しい op の追加のたびにコアロジックを変更しなければならず、デグレードリスクが高い。また、効果の動作を個別にテストしにくい。

## Decision

各カード効果を `CardEffectCommand` 抽象基底クラスのサブクラスとして実装する：

- `lib/domain/commands/card_effect_command.dart`: 抽象基底クラス（`execute(GameState)` メソッドを定義）
- 各 op（draw、destroy、mill 等）を独立した具象クラスとして実装
- `lib/domain/commands/operation_executor.dart`（OperationExecutor / CommandFactory）が `op` 文字列をキーにコマンドオブジェクトを生成

## Consequences

**Positive:**
- 各コマンドを `GameState` のモックを使って完全に独立してテストできる。
- 新しい op の追加は新クラス + ファクトリ登録のみ。既存コードへの変更が最小限。
- リプレイ機能（F-013）の実装が容易：コマンドシーケンスを記録・再生できる。

**Negative:**
- op の種類が増えるにつれてクラス数が増加する。
- ファクトリの `op` 文字列と YAML の定義を常に同期して維持する必要がある。

## References

- `lib/domain/commands/card_effect_command.dart`
- `lib/domain/commands/operation_executor.dart`
- `docs/SOFTWARE_ARCHITECTURE.md` §5.1〜§5.2
- `docs/CARD_YAML_SPEC.md`（op の定義）
