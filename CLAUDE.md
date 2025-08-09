# ソリティアTCG（非同期デュエル）— 開発計画（Claude Code向け / Flutter + Flame）

> **目的**：演出・チート防止は後回し。**カード連鎖（ソリティア）の気持ちよさ**を最短で体験できるMVPを実装する。
> **エンジン要件の肝**：
>
> * **カード種別**＝`monster / spell / equip / artifact / field`
> * **コスト廃止**：必要リソースは**効果として**破壊・捨てる
> * **チェーンなし**：誘発は**発生順（FIFO）で自動解決**
> * **フィールド裁定**：新フィールドの`on_play`→旧フィールド破壊→旧`on_destroy`が**後で**自動処理

---

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

---

## 2. 機能要件（MVP）

* **デッキ構築**：カード検索/追加/保存（ローカル）
* **対戦**：1ターン内でカードをプレイ → 効果解決 → 勝敗判定
* **モード**：

  * **パズル**（運排除）：初期手札/盤面固定で挑戦
  * **ランダム**（運あり）：シャッフル、N回試行で成功率表示
* **フィールド裁定**：場は常に1枚。新`on_play`→旧破壊→旧`on_destroy`が**キュー末尾**で解決
* **オートリゾルブ**：誘発は発生順に自動処理（FIFO）。ユーザー選択なし
* **ログ**：効果解決の簡易ログ（デバッグ兼用）

---

## 3. 非機能・制約（MVP）

* フレーム60fps目標（Flame標準でOK）
* オフライン動作（カード定義はアセット）
* エラー時は\*\*“不発”でスキップ\*\*してゲーム継続（クラッシュ回避）

---

## 4. ディレクトリ構成（提案）

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
```

---

## 5. カードDSL（YAML）最小スキーマ

```yaml
id: string
name: string
type: monster | spell | equip | artifact | field
tags: [string, ...]
text: string
version: 1

stats: { atk: 0, hp: 0 }                 # monster任意
equip: { valid_targets: ["monster"] }     # equip任意
field: { unique: true }                   # field任意（省略時true）

abilities:
  - when: on_play | on_enter | on_destroy | static | activated | on_draw | on_discard | on_field_set
    condition: "expr" | null
    priority: 0                           # 基本未使用。同tick内の順序ヒント
    effect:
      - { op: require, expr: "hand.count >= 1" }
      - { op: discard, from: hand, count: 1 }
      - { op: draw, count: 2 }
      # ops: draw/mill/discard/move/destroy/summon/equip_to/unequip
      #      search{from,to,filter,max}/counter/modify_stat
      #      win_if{expr}/lose_if{expr}/set_field/require{expr}
```

**expr参照子例**：`hand.count`, `deck.count`, `grave.count`, `field.exists`,
`spells_cast_this_turn`, `unique_fields_in_grave`, `count(tag:"field", zone:"grave")`
**演算**：`> >= < <= == != && || !`

---

## 6. ルール要点（実装規約）

### 6.1 コスト廃止

* すべて“効果”で消費。支払いが無理なら**require**でガード、失敗時**不発**。

### 6.2 誘発スタック（オート解決）

* **FIFO**で自動解決。処理中に発生した誘発は**末尾に追加**。
* 優先度を付けたいカードだけ `priority`（同tickに限る）を使用。

**擬似コード**

```dart
int tick = 0;
final Queue<Trigger> q = Queue();

void enqueue(Trigger t) { t.order = ++tick; q.addLast(t); }
void resolveAll() {
  while (q.isNotEmpty) {
    final t = q.removeFirst();
    resolveEffects(t.effects); // 実行中に発生した誘発は enqueue される
  }
}
```

### 6.3 フィールド上書き裁定（本作のキモ）

1. 新フィールドを**場に置く**
2. **新フィールドの on\_play を即時実行**（発生誘発は通常どおりキューへ）
3. 旧フィールドを破壊 → **旧 on\_destroy** を**キュー末尾**へ
4. `resolveAll()` で順次自動解決

---

## 7. 代表opsの挙動（MVP）

* `draw{count}`：デッキ→手札。枯渇時は**可能な分だけ**
* `discard{from: hand, count}`：不足時は**不発**（以降のステップ停止）
* `search{from,to,filter,max}`：filter＝`type|tag|name`（AND想定）。見つからなければ0件
* `move{from,to,target,count}`：ゾーン間移動（`target: "self"|"top"|"any"` など最小）
* `win_if{expr}`：exprが真なら**勝利**
* `require{expr}`：偽なら**以降不発**
* `destroy{target}`：対象を墓地へ。フィールドなら破壊誘発を**enqueue**

---

## 8. 例カード（MVP動作確認用）

```yaml
# 残響の講堂
id: fld_x01
name: 残響の講堂
type: field
abilities:
  - when: on_play
    effect:
      - { op: draw, count: 2 }
  - when: on_destroy
    effect:
      - { op: search, from: deck, to: hand, filter: { type: "field" }, max: 1 }
```

```yaml
# 記憶の温室
id: fld_x02
name: 記憶の温室
type: field
abilities:
  - when: on_play
    effect:
      - { op: search, from: deck, to: hand, filter: { type: "spell" }, max: 1 }
  - when: on_destroy
    effect:
      - { op: draw, count: 1 }
```

```yaml
# 閃考の儀（支払いは効果の先頭）
id: spl_x07
name: 閃考の儀
type: spell
abilities:
  - when: on_play
    effect:
      - { op: discard, from: hand, count: 1 }
      - { op: win_if, expr: "spells_cast_this_turn >= 7" }
```

---

## 9. 画面と入出力（MVP）

* **Deck Builder**：カードリスト、検索、デッキ枠、保存/読込
* **Battle**：手札/山札/墓地/場の簡易UI、**プレイ→自動解決→ログ表示**、倍速トグル
* **モード切替**：パズル（固定初期手札/盤面）／ランダム（シャッフル・N試行）

---

## 10. スプリント計画

### Sprint 1（1–2週）エンジン骨格

* [ ] DSLローダ（`yaml`）＋型（`types.dart`）
* [ ] ゾーン/状態（hand/deck/field/grave/banish）
* [ ] ops：`require/draw/discard/search/move/destroy/win_if`
* [ ] 誘発キュー（FIFO）/ `resolveAll()`
* [ ] **フィールド上書き裁定**ユニットテスト

**完了基準**：CLIまたは最小UIで「フィールド2枚連続→新on\_play→旧on\_destroy」が自動解決

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

---

## 11. テスト観点（Vitest相当はDart test）

* **フィールド置換**：`fld_x01`→`fld_x02` 上書きで **新on\_play→旧on\_destroy** の順にログが出る
* **require不発**：手札0で `require hand>=1 → discard1 → draw2` は**不発**としてログ
* **FIFO保証**：同時誘発3件が**発生順**で解決されること
* **ランダムモード**：同シードで結果が再現すること

---

## 12. 命名 / コーディング規約

* ファイル：`snake_case.dart`、型：`UpperCamelCase`、変数：`lowerCamelCase`
* public API に DartDoc、opsは**純関数的**に（`GameState`を受け取り変更を返す or 明示的にミューテート）
* 例外は投げず、**不発**としてログに残す

---

## 13. Claude Code への最初の依頼（実行タスク）

1. `lib/engine/types.dart`：Card/Ability/EffectStep/Zone/GameState の型定義を作成
2. `lib/engine/loader.dart`：上記DSLを`yaml`から読み込むパーサ（バリデーション含む）
3. `lib/engine/stack.dart`：FIFOキューと`resolveAll()`の骨格
4. `lib/engine/ops.dart`：`require/draw/discard/search/move/destroy/win_if` の最小実装
5. `lib/engine/field_rule.dart`：**フィールド上書き裁定**の関数`playField(Card)`
6. `assets/cards/` にサンプル3枚（上記YAML）を配置し、`index.yaml`で読み込む
7. `test/` にフィールド置換・FIFO・require不発の3テスト

> 以上を生成したら、`main.dart`に最小のFlameシーン（手札プレイ→自動解決ログ表示）を追加。
