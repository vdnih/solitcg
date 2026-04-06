# SoliTCG

TCG 風ソリティアゲーム。対戦相手なしに、カード連鎖のコンボを設計・実行する体験を提供する。
Flutter/Flame で開発し、Web ブラウザ上で即座にプレイできる。

## アーキテクチャ

3層レイヤードアーキテクチャ（Presentation / Domain / Data）を採用。
GameState が Single Source of Truth として全ゲーム状態を管理し、カード効果はコマンドパターンで実装する。

詳細は `docs` ディレクトリ内のドキュメントを参照。

## ドキュメント

| ドキュメント | 説明 |
|---|---|
| [PRODUCT_VISION.md](docs/PRODUCT_VISION.md) | Mission・Vision・Values（プロダクトの憲法） |
| [PRD.md](docs/PRD.md) | フェーズ別機能一覧・非機能要件 |
| [SPEC.md](docs/SPEC.md) | エンジンビジネスルール仕様 |
| [SOFTWARE_ARCHITECTURE.md](docs/SOFTWARE_ARCHITECTURE.md) | ソフトウェアアーキテクチャ設計 |
| [FIREBASE_ARCHITECTURE.md](docs/FIREBASE_ARCHITECTURE.md) | Firebase インフラ設計 |
| [TESTING_POLICY.md](docs/TESTING_POLICY.md) | テスト方針 |
| [CARD_YAML_SPEC.md](docs/CARD_YAML_SPEC.md) | カード定義 YAML スキーマ |
| [GAME_RULES.md](docs/GAME_RULES.md) | プレイヤー向けゲームルール |
| [feature_registry.md](docs/feature_registry.md) | 機能 ID とコード/テストパスの対応表 |
| [adr/](docs/adr/) | Architecture Decision Records |

## はじめに

### 前提条件

- Flutter SDK 3.x
- Dart SDK

### インストール

```bash
git clone <repository-url>
cd solitcg
flutter pub get
```

### 実行

```bash
# Web デモ（推奨）
flutter run -d chrome

# その他のプラットフォーム
flutter run
```

### テスト

```bash
flutter test
```

### ビルド（Web）

```bash
flutter build web --web-renderer canvaskit
```

## ディレクトリ構造

```
lib/
├── core/           # GameState（ゲーム全状態の SSoT）
├── data/           # Repository（YAML 読み込み・Firestore 通信）
├── domain/         # モデル・サービス・コマンド（ゲームロジック）
├── presentation/   # Flame コンポーネント・ゲーム本体
├── providers/      # デッキ状態管理
└── ui/             # Flutter 画面
assets/
└── cards/          # YAML 定義のカードデータ
docs/               # 設計ドキュメント
```

## ライセンス

- Engine code: [MIT License](./LICENSE)
- Card data: [CC BY 4.0](./CARD_LICENSE)
