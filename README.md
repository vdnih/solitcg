# solitcg

SoliTCG は Dart/Flutter 製の実験的なカードゲームエンジンです。
YAML で定義されたカードデータを読み込み、シンプルなゲームロジックを実装しています。

## Getting Started

1. Flutter と Dart の開発環境を用意します。
2. 依存パッケージを取得します。

   ```bash
   flutter pub get
   ```

3. Web デモを起動します。

   ```bash
   flutter run -d chrome
   ```

## Tests

ユニットテストは次のコマンドで実行できます。

```bash
dart test
```

## Documentation

詳細な仕様は `docs` ディレクトリを参照してください。

- `CARD_YAML_SPEC.md` — カード定義の YAML 仕様
- `GAME_RULES.md` — 基本的なルール概要
