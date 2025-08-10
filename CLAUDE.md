# ソリティアTCG — 開発計画（Claude Code向け）

> **目的**：演出・チート防止は後回し。**カード連鎖（ソリティア）の気持ちよさ**を最短で体験できるMVPを実装する。
>
> **ゲームルール詳細**: [GAME_RULES.md](./docs/GAME_RULES.md) を参照してください。

## 1. 環境 / 技術スタック

* **Flutter 3.x**
* **Flame**（2Dゲームループ＆描画）
* **Dart**（null-safety）
* 依存（最小）：`flame`, `flutter_riverpod`（任意）, `yaml`（DSL読込）, `collection`
* 対応：Android / iOS / Web / Desktop（dev想定：Web/Android）

**pubspec（抜粋）**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.11.0
  yaml: ^3.1.2
  collection: ^1.18.0
  flutter_riverpod: ^2.5.0   # 任意（状態管理が楽になる）
```

## 2. 機能要件（MVP）

* **デッキ構築**：カード検索/追加/保存（ローカル）
* **対戦**：1ターン内でカードをプレイ → 効果解決 → 勝敗判定
* **モード**：パズル（運排除）/ ランダム（N試行で成功率表示）
* **ログ**：効果解決の簡易ログ（デバッグ兼用）

## 3. 非機能・制約（MVP）

* フレーム60fps目標（Flame標準でOK）
* オフライン動作（カード定義はアセット）
* エラー時は**"不発"でスキップ**してゲーム継続（クラッシュ回避）

## 4. ディレクトリ構成

```
lib/
  main.dart
  game/
    tcg_game.dart           # FlameGame派生、描画とUIブリッジ
    renderer.dart           # 盤面/手札などの簡易描画
  engine/
    types.dart              # Card/Ability/Effect/Zone/GameState 型
    loader.dart             # YAML→モデル。バリデーションもここ
    ops.dart                # draw/move/discard/search/destroy/win_if/require...
    stack.dart              # 誘発キュー（FIFO）と resolveAll()
    evaluator.dart          # expr評価(hand.count等)
    field_rule.dart         # フィールド上書き裁定
    rng.dart                # 乱数シード（ランダムモード）
    modes.dart              # パズル/ランダムの進行ヘルパ
  ui/
    deck_builder_page.dart
    battle_page.dart
    widgets/...
assets/
  cards/
    index.yaml
    fld_x01.yaml
    fld_x02.yaml
    spl_x07.yaml
docs/
  GAME_RULES.md             # ゲームルールの詳細
```

## 5. 画面と入出力（MVP）

* **Deck Builder**：カードリスト、検索、デッキ枠、保存/読込
* **Battle**：手札/山札/墓地/場の簡易UI、**プレイ→自動解決→ログ表示**、倍速トグル
* **モード切替**：パズル（固定初期手札/盤面）／ランダム（シャッフル・N試行）

## 6. スプリント計画

### Sprint 1（1–2週）エンジン骨格

* [ ] DSLローダ（`yaml`）＋型（`types.dart`）
* [ ] ゾーン/状態（hand/deck/field/grave/banish）
* [ ] ops：`require/draw/discard/search/move/destroy/win_if`
* [ ] 誘発キュー（FIFO）/ `resolveAll()`
* [ ] **フィールド上書き裁定**ユニットテスト

**完了基準**：CLIまたは最小UIで「フィールド2枚連続→新on_play→旧on_destroy」が自動解決

### Sprint 2（1–2週）UI & モード

* [ ] Flame上で手札/場の簡易表示＋クリックでプレイ
* [ ] ログ・倍速
* [ ] パズル/ランダムの切替、ランダムはN試行で成功率表示
* [ ] 代表カード20枚投入

**完了基準**：ブラウザ実行で**ワンターン勝利**体験可

### Sprint 3（1週）品質

* [ ] 入力ログ保存＆リプレイ（簡易）
* [ ] 無限反復ガード（アクション上限100）
* [ ] カード定義のホットリロード（dev）

## 7. テスト観点

* **フィールド置換**：`fld_x01`→`fld_x02` 上書きで **新on_play→旧on_destroy** の順にログが出る
* **require不発**：手札0で `require hand>=1 → discard1 → draw2` は**不発**としてログ
* **FIFO保証**：同時誘発3件が**発生順**で解決されること
* **ランダムモード**：同シードで結果が再現すること

## 8. 命名 / コーディング規約

* ファイル：`snake_case.dart`、型：`UpperCamelCase`、変数：`lowerCamelCase`
* public API に DartDoc、opsは**純関数的**に（`GameState`を受け取り変更を返す or 明示的にミューテート）
* 例外は投げず、**不発**としてログに残す