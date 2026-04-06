# ADR-005: YAML 駆動カードデータシステム

## Status
Accepted

## Date
2025-10-22

## Context

カードゲームエンジンとカードデータを結合させると、新しいカードを追加するたびにコードの変更・コンパイル・デプロイが必要になる。
また、ゲームデザイナー（コードを書かない役割）がカードを定義できる環境が望ましい。

## Decision

カードデータは `assets/cards/*.yaml` に YAML ファイルとして定義し、エンジンが実行時に読み込む方式を採用する。

- カードの定義スキーマは `docs/CARD_YAML_SPEC.md` で管理する。
- `lib/data/repositories/card_repository.dart` がYAML を `CardData` モデルへパースする責務を担う。
- エンジンは `CardData` に依存し、YAML の実装詳細を知らない。
- カードを追加・変更するには YAML ファイルの編集のみで足り、Dart コードの変更は不要。
  （ただし新しい `op` が必要な場合は `OperationExecutor` の更新が必要）

## Consequences

**Positive:**
- カードの追加・調整はコーディング知識なしに YAML を編集するだけでよい。
- 将来的に外部カードデータ（Cloud Firestore 等）からのロードに切り替えやすい。
- カードデータとエンジンを独立してバージョン管理できる。

**Negative:**
- YAML スキーマの変更（新フィールド追加等）は既存カードの更新を伴う可能性がある。
- `CardData` の Dart モデルと YAML スキーマの整合性を手動で維持する必要がある。

## References

- `assets/cards/`
- `lib/data/repositories/card_repository.dart`
- `lib/domain/models/card_data.dart`
- `docs/CARD_YAML_SPEC.md`
