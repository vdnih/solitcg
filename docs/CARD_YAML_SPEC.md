# docs/CARD_YAML_SPEC.md（v0.6.0）

この文書は、**SoliTCG** の **カード定義ファイル（YAML）** の仕様です。
エンジンはこの形式の YAML を読み込み、カードの挙動を決定します。

---

## 0. 基本ルール

* 文字コードは **UTF-8**。拡張子は **`.yaml`**。
* 1ファイル＝1枚のカード定義。
* 予約語・列挙値は **小文字** で統一。
* 不正キーや型違いは読み込み時にエラーとすることを推奨。

---

## 1. トップレベルスキーマ

```yaml
id: string                    # 必須。一意ID（英数字/アンダースコア推奨）
name: string                  # 必須。表示名
type: monster | ritual | spell | arcane | equip | artifact | relic | domain   # 必須
tags: [string, ...]           # 任意。検索・相互作用用タグ
text: string                  # 必須。プレイヤー向け説明（自由記述）
version: integer              # 必須。カードデータの版番号

# monster / ritual のみ。hp 必須、atk / def は任意（効果参照用）
stats:
  atk: integer (>=0)          # 攻撃力（任意。効果の参照値として使用）
  def: integer (>=0)          # 防御力（任意。効果の参照値として使用）
  hp:  integer (>=0)          # 必須。hp <= 0 で即破壊 → on_destroy 発動

abilities:                    # 任意。0個以上
  - when: on_play | on_destroy | on_discard | activated
    pre: [ "expr", ... ]      # 発動前提（すべてtrue時のみ実行）
    effect:                   # 実行ステップ（配列）
      - { op: operation_name, ...params }
      - ...
```

> `priority` フィールドは廃止。同時トリガーはプレイヤーが投入順を選択する。

---

## 2. `type`ごとのルール

| type     | `stats`必須 | 備考 |
| -------- | --------- | ---- |
| monster  | 必須（hp のみ必須、atk/def は任意） | hp <= 0 で破壊 |
| ritual   | 必須（monster 同様） | エクストラ編入可 |
| spell    | 不要 | 使い切り効果カード。プレイ後に墓地へ |
| arcane   | 不要 | 強力効果カード。プレイ後に墓地へ。エクストラ編入可 |
| equip    | 不要 | 装備型カード |
| artifact | 不要 | 永続系 |
| relic    | 不要 | artifact 互換扱い。エクストラ編入可 |
| domain   | 不要 | 場全体に影響。同時に1枚制限 |

---

## 3. `when`（発動タイミング）

| 値 | 発火タイミング |
| --- | --- |
| `on_play` | 手札からプレイした直後（サーチ・移動では発火しない） |
| `on_destroy` | hp ≤ 0 または `destroy` op により破壊された直後 |
| `on_discard` | 手札から捨て札に置かれた直後 |
| `activated` | プレイヤーが手動で発動（**1ターン1度制限**はエンジンが強制） |

> MVP スコープ外（使用不可）: `on_enter` / `static` / `on_draw` / `on_domain_set`

---

## 4. `pre`（発動前提）

* 文字列式の配列。**全てtrue**の場合のみ発動。
* 状態参照のみ。動作（カード移動・破壊など）は禁止。
* 一度trueで発動が始まれば、解決中に条件が変化しても続行。

**式例：**

```yaml
pre:
  - "count(type:'artifact', zone:'board:self') >= 2"
  - "hand.count >= 3"
```

利用可能な参照例：

* ゾーン数：`hand.count`, `deck.count`, `grave.count`
* タグ/タイプ数：`count(type:'artifact', zone:'board:self')`, `count(tag:'dragon', zone:'hand:self')`
* カウンタ：`spells_cast_this_turn`
* 比較演算：`> >= < <= == != && || !`

---

## 5. `effect`（効果ステップ）

* 配列で順次実行。
* 先頭に「消費」処理を書くのが慣習（例：破壊、移動など）。
* 効果中に `win` / `win_if` が成立した場合は即時勝利し残りは解決せず終了。

---

## 6. サポートする `op`（MVP版）

### 6.1 カード移動・破壊

```yaml
- { op: destroy, target: "choose:self:artifact", count: 1 }
- { op: move, from: hand, to: grave, target: "choose:self:any", count: 1 }
- { op: search, from: deck, to: hand, filter: { type: "domain" }, max: 1 }
```

* `from` / `to`: `hand | deck | grave | board | domain | extra`
* `count`: 数。省略時は可能な限り全て。
* `target`: 対象記法（後述）。`move` op でも使用可能。

### 6.2 手札操作

```yaml
- { op: draw, count: 2 }
- { op: discard, from: hand, count: 1, selection: choose }
```

* `selection`: `choose`（プレイヤー選択）または `random`。**省略時のデフォルトは `choose`**。

### 6.3 ステータス操作

```yaml
- { op: modify_stat, target: "choose:self:monster", atk: +500, hp: -1 }
```

* `hp <= 0` で即破壊 → `on_destroy` 誘発。

### 6.4 勝敗条件

```yaml
- { op: win }                                          # 無条件勝利
- { op: win_if, expr: "spells_cast_this_turn >= 7" }   # 条件付き勝利
- { op: lose_if, expr: "hand.count == 0 && deck.count == 0" }
```

### 6.5 ドメイン操作

```yaml
- { op: set_domain, card: "dom_echo_hall" }
```

* 新ドメインの `on_play` → 旧ドメイン移送 → 旧 `on_destroy` の順で自動処理（詳細は `SPEC.md §6`）。

---

## 7. ターゲット記法

`"{scope}:{owner}:{selector}"`

* scope: `choose | one | all | random | top | bottom`
* owner: `self | any`（MVP では対戦相手なし）
* selector: `monster | ritual | spell | arcane | artifact | relic | domain | any` または `tag=xxx`

例：

* `choose:self:artifact` → 自分の場のアーティファクトからプレイヤーが選択
* `all:self:monster` → 自分の場のモンスター全て
* `random:self:any` → 自分の場のカードからランダム

---

## 8. カード例

### ドロー＋捨て

```yaml
id: spl_typhoon
name: タイフーン
type: spell
text: カードを2枚引く。その後、手札を2枚選んで捨てる。
version: 1
abilities:
  - when: on_play
    effect:
      - { op: draw, count: 2 }
      - { op: discard, from: hand, count: 2, selection: choose }
```

### 消費→効果

```yaml
id: ex_arc_001
name: 天象の秘儀
type: arcane
text: 自分のアーティファクト2枚を破壊してカードを5枚引く。
version: 1
abilities:
  - when: on_play
    pre:
      - "count(type:'artifact', zone:'board:self') >= 2"
    effect:
      - { op: destroy, target: "choose:self:artifact", count: 2 }
      - { op: draw, count: 5 }
```

### 無条件勝利

```yaml
id: spl_victory
name: 大逆転
type: spell
text: 手札を3枚捨てて勝利する。
version: 1
abilities:
  - when: on_play
    pre:
      - "hand.count >= 3"
    effect:
      - { op: discard, from: hand, count: 3, selection: choose }
      - { op: win }
```

### activated（1ターン1度）

```yaml
id: atf_crystal_001
name: クリスタルコア
type: artifact
text: 1ターンに1度、手札を2枚捨ててカードを3枚引く。
version: 1
abilities:
  - when: activated
    pre:
      - "hand.count >= 2"
    effect:
      - { op: discard, from: hand, count: 2, selection: choose }
      - { op: draw, count: 3 }
```
