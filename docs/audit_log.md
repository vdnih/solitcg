# アーキテクチャ監査ログ

重要な設計・アーキテクチャ判断の時系列記録。
詳細な根拠は各 ADR（`docs/adr/`）を参照。

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

## 2026-04-06 00:00 - [Docs] ドキュメント体系整備

- **判断内容**: `my_career_app` / `travel_log_app` に倣いドキュメント構成を整備。PRODUCT_VISION.md・PRD.md・SPEC.md・feature_registry.md・audit_log.md・adr/ を新設。CLAUDE.md を全面改訂。
- **理由**: AI エージェントが設計意図を正確に把握し、一貫した開発スタイルを維持するため
- **影響範囲**: `docs/` 全体、`CLAUDE.md`、`README.md`
- **ADR**: なし（ドキュメント整備のため）
