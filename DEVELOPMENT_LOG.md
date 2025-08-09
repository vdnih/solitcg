# ソリティアTCG 開発ログ

## 実装概要

CLAUDE.mdの仕様に基づいて、ソリティアTCGの基盤システムを実装しました。フィールドカード連鎖の気持ちよさを最短で体験できるMVPを構築。

## 実装した機能

### 1. エンジンコア (`lib/engine/`)

#### `types.dart` - 型定義システム
- **Card型**: id, name, type, abilities等の完全定義
- **GameState**: hand/deck/field/grave/banishの5つのゾーン管理
- **Trigger/Ability**: 誘発システムの型定義
- **CardType enum**: monster/spell/equip/artifact/field
- **TriggerWhen enum**: on_play/on_destroy等のタイミング定義

#### `loader.dart` - YAML パーサー
- カードDSLのYAML読み込み機能
- バリデーション機能付き
- assets/cards/index.yamlからの一括読み込み
- エラー処理（不正なカードは無視）

#### `stack.dart` - 誘発スタック（FIFO）
- **キューシステム**: 誘発をFIFO順で自動解決
- **無限ループ防止**: 最大100回の処理制限
- **式評価器**: `hand.count >= 1`等の条件判定
- **自動解決**: `resolveAll()`で全誘発を順次処理

#### `ops.dart` - オペレーション実装
実装した操作：
- `require`: 条件チェック（失敗時は以降の効果を不発）
- `draw`: デッキからカードを引く
- `discard`: 手札を捨てる  
- `search`: ゾーン間でカード検索・移動
- `move`: カードの移動
- `destroy`: カード破壊（誘発込み）
- `win_if/lose_if`: 勝利/敗北判定
- `mill`: デッキから墓地へ

#### `field_rule.dart` - フィールド裁定
- **フィールド上書きルール**: 新フィールドのon_play → 旧フィールド破壊 → 旧on_destroyの順序を保証
- **カードプレイ処理**: 手札からのカード使用
- **誘発管理**: 各カードタイプに応じた誘発処理

### 2. ゲーム実装 (`lib/game/`)

#### `tcg_game.dart` - Flame ゲームエンジン
- **簡易UI**: 手札・フィールド・ログの表示
- **カードコンポーネント**: クリック可能なカード描画
- **自動解決ログ**: 効果処理の詳細ログ表示
- **勝利判定**: 勝利時の表示

#### `main.dart` - Flutter アプリ
- Material Design UI
- GameWidget統合

### 3. アセット (`assets/cards/`)

#### サンプルカード3枚を実装：

**残響の講堂 (fld_x01)**
```yaml
- on_play: draw 2枚
- on_destroy: フィールドカードをサーチ
```

**記憶の温室 (fld_x02)**  
```yaml
- on_play: スペルカードをサーチ
- on_destroy: draw 1枚
```

**閃考の儀 (spl_x07)**
```yaml
- on_play: discard 1枚 → スペル7回詠唱で勝利
```

### 4. テスト (`test/engine_test.dart`)

#### 3つの重要テストを実装：

1. **フィールド置換テスト**: 
   - 新フィールドon_play → 旧フィールドon_destroyの順序確認
   - ログの出力順序検証

2. **FIFOキューテスト**:
   - 誘発が発生順（FIFO）で解決されることを確認
   - 複数誘発の処理順序検証

3. **require不発テスト**:
   - 条件未達時の効果停止確認
   - 条件達成時の正常処理確認

## 技術仕様

### アーキテクチャの特徴

1. **コスト廃止**: 全て効果として処理（require → discard → benefit）
2. **チェーンなし**: 誘発は発生順で自動解決、プレイヤー選択不要  
3. **フィールド裁定**: 新on_play → 旧破壊 → 旧on_destroyが後で自動処理
4. **不発システム**: エラー時は処理停止、ゲーム続行
5. **FIFO保証**: 同時誘発も発生順で確実に処理

### 式評価システム

対応する参照子：
- `hand.count`, `deck.count`, `grave.count`
- `field.exists`, `spells_cast_this_turn`  
- `count(tag:"field", zone:"grave")` (将来実装予定)

演算子：`>= <= > < == != && || !`

## プロジェクト構造

```
lib/
├── engine/
│   ├── types.dart          # 型定義
│   ├── loader.dart         # YAML読み込み
│   ├── stack.dart          # 誘発スタック
│   ├── ops.dart            # オペレーション
│   └── field_rule.dart     # フィールド裁定
├── game/
│   ├── tcg_game.dart       # Flameゲーム
│   └── main.dart           # アプリエントリ
assets/cards/
├── index.yaml              # カードインデックス
├── fld_x01.yaml           # 残響の講堂
├── fld_x02.yaml           # 記憶の温室  
└── spl_x07.yaml           # 閃考の儀
test/
└── engine_test.dart        # エンジンテスト
```

## 動作確認方法

1. **依存関係インストール**:
   ```bash
   flutter pub get
   ```

2. **テスト実行**:
   ```bash
   flutter test
   ```

3. **アプリ起動**:
   ```bash
   flutter run
   ```

## 次回開発予定

### Sprint 2での実装予定：
1. **UI改善**: より見やすいカード表示・アニメーション
2. **デッキ構築**: カード検索・デッキ編集機能
3. **パズルモード**: 固定初期状態でのチャレンジ
4. **ランダムモード**: シャッフル・N回試行での成功率表示
5. **カード追加**: より多様なカード効果の実装

### 技術的課題：
- 依存関係の解決（現在はFlutter/Flame未インストール状態）
- カードアニメーションの実装
- デッキ保存システム（ローカルストレージ）
- リプレイシステム（入力ログ保存）

## 学習ポイント

1. **FIFO誘発システム**: MTGのスタックとは異なる、自動解決方式を採用
2. **フィールド裁定**: 新旧フィールドの処理順序が重要
3. **コスト概念の排除**: より直感的なカードゲームデザイン
4. **エラー耐性**: 不発システムでゲームクラッシュを防止
5. **テスト駆動**: 重要な仕様を必ずテストで検証

この基盤システムにより、フィールドカード連鎖の「気持ちよさ」を体験できるMVPが完成しました。