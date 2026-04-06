# ADR-003: Firebase サーバーレス構成（Cloud Functions なし）

## Status
Accepted

## Date
2025-10-22

## Context

バックエンドとして Firebase を採用する場合、Cloud Functions を使いサーバーサイドでゲームロジックを検証するか、クライアントサイドで完結するサーバーレス構成にするかの選択が生じる。

サーバーサイドバリデーションはチート対策として有効だが、ゲームループの遅延増加・実装コスト・維持コストが伴う。

## Decision

Cloud Functions を使わず、クライアントサイドで完結するサーバーレス構成を採用する。

使用するサービス：
- **Firebase Authentication**: Google Sign-In によるプレイヤー認証
- **Cloud Firestore**: デッキ構成・プレイヤーデータの永続化
- **Cloud Storage for Firebase**: カードアセット・アバター画像
- **Firebase Hosting**: Web ゲームの CDN 配信

## Consequences

**Positive:**
- ゲームループがネットワーク遅延の影響を受けない（すべてクライアントで解決）。
- Cloud Functions の開発・デプロイ・維持コストが不要。
- MVP フェーズで十分なシンプルさ。

**Negative:**
- ゲームロジック（勝敗判定）がクライアント側で行われるため、スコア改ざんが技術的に可能。
- **許容理由**: 個人開発スケール・PvP なしのソリティア型ゲームであり、厳密なサーバーサイドバリデーションのコストが見合わない。チート耐性より開発速度と体験品質を優先する。

## References

- `docs/FIREBASE_ARCHITECTURE.md` §6.1（チート対策リスクの記載）
- `lib/data/repositories/`
- `lib/firebase_options.dart`
