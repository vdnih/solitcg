了解です。
いただいた v0.4.3 の仕様をベースにしつつ、**banish** を完全に削除し、ルール・構造をできるだけシンプルにした軽量版のカード仕様書を作ります。
バージョンはひとまず **v0.5.0** として整理します。

---

# docs/CARD\_YAML\_SPEC.md（v0.5.0）

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

# monster / ritual のみ必須
stats:
  atk: integer (>=0)
  def: integer (>=0)
  hp:  integer (>=0)          # hp <= 0 で即破壊 → on_destroy 発動

abilities:                    # 任意。0個以上
  - when: on_play | on_destroy | on_discard | activated | static
    pre: [ "expr", ... ]      # 発動前提（すべてtrue時のみ実行）
    priority: integer         # 解決順制御。デフォルト0。大きいほど後に解決
    effect:                   # 実行ステップ（配列）
      - { op: operation_name, ...params }
      - ...
```

---

## 2. `type`ごとのルール

| type     | `stats`必須 | 備考               |
| -------- | --------- | ---------------- |
| monster  | 必須        | atk/def/hp すべて必要 |
| ritual   | 必須        | monster同様        |
| spell    | 不要        | 使い切り効果カード        |
| arcane   | 不要        | 強力効果カード          |
| equip    | 不要        | 装備型カード           |
| artifact | 不要        | 永続系              |
| relic    | 不要        | artifact互換扱い     |
| domain   | 不要        | 場全体に影響、通常1枚制限    |

---

## 3. `when`（発動タイミング）

| 値            | 発火タイミング     |
| ------------ | ----------- |
| `on_play`    | プレイ（場に出す）直後 |
| `on_destroy` | 破壊された直後     |
| `on_discard` | 捨て札に置かれた直後  |
| `activated`  | プレイヤー操作で発動  |
| `static`     | 常時効果        |

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

* ゾーン数：`hand.count`, `deck.count`, `grave.count`, `board.count(type:'artifact')`
* タグ/タイプ数：`count(tag:'dragon', zone:'board:self')`
* カウンタ：`spells_cast_this_turn`
* 比較演算：`> >= < <= == != && || !`

---

## 5. `effect`（効果ステップ）

* 配列で順次実行。
* 先頭に「消費」処理を書くのが慣習（例：破壊、移動など）。
* 効果中に `win_if` が成立した場合は即時勝利し残りは解決せず終了。

---

## 6. サポートする `op`（MVP版）

### 6.1 カード移動・破壊

```yaml
- { op: destroy, target: "choose:self:artifact", count: 1 }
- { op: move, from: hand, to: grave, target: "choose:self:any", count: 1 }
- { op: search, from: deck, to: hand, filter: { type: "domain" }, max: 1 }
```

* `from` / `to`: `hand|deck|grave|board|domain|extra`
* `count`: 数。省略時は可能な限り全て。
* `target`: 対象記法（後述）。
* **banishは存在しない。**

### 6.2 手札操作

```yaml
- { op: draw, count: 2 }
- { op: discard, from: hand, count: 1, selection: choose }
```

* `selection`: `choose`（選択）または`random`。

### 6.3 ステータス操作

```yaml
- { op: modify_stat, target: "choose:self:monster", atk: +500, hp: -1 }
```

* `hp <= 0` で即破壊 → on\_destroy誘発。

### 6.4 勝敗条件

```yaml
- { op: win_if, expr: "spells_cast_this_turn >= 7" }
- { op: lose_if, expr: "hand.count == 0 && deck.count == 0" }
```

### 6.5 ドメイン操作

```yaml
- { op: set_domain, card: "dom_echo_hall" }
```

* 新ドメインの `on_play` → 旧ドメイン破壊 → 旧`on_destroy`の順で自動処理。

---

## 7. ターゲット記法

`"{scope}:{owner}:{selector}"`

* scope: `choose|one|all|random|top|bottom`
* owner: `self|opponent|any`
* selector: `monster|ritual|spell|arcane|artifact|relic|domain|any` または `tag=xxx`

例：

* `choose:self:artifact` → 自分の場のアーティファクトから選択
* `all:opponent:monster` → 相手の場のモンスター全て

---

## 8. カード例

### 手札を1枚選んで捨てる

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
