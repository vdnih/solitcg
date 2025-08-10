# ソリティアTCG - ゲームルール

> **概要**：カード連鎖（ソリティア）の気持ちよさを体験できるカードゲーム。
> コストを廃止し、誘発の自動解決、フィールド裁定などを特徴とする。

## 1. カード種別

* `monster` - モンスターカード
* `spell` - スペルカード
* `equip` - 装備カード
* `artifact` - アーティファクト
* `field` - フィールドカード

## 2. 基本ルール

### 2.1 コスト廃止

* すべて"効果"として消費。支払いが無理なら**require**でガード、失敗時**不発**。

### 2.2 誘発スタック（オート解決）

* **FIFO**（First In, First Out）で自動解決。処理中に発生した誘発は**末尾に追加**。
* 優先度を付けたいカードだけ `priority`（同tickに限る）を使用。

**誘発処理の仕組み:**

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

### 2.3 フィールド上書き裁定（本作のキモ）

1. 新フィールドを**場に置く**
2. **新フィールドの on_play を即時実行**（発生誘発は通常どおりキューへ）
3. 旧フィールドを破壊 → **旧 on_destroy** を**キュー末尾**へ
4. `resolveAll()` で順次自動解決

## 3. 効果操作（ops）の挙動

* `draw{count}` - デッキ→手札。枯渇時は**可能な分だけ**
* `discard{from: hand, count}` - 不足時は**不発**（以降のステップ停止）
* `search{from,to,filter,max}` - filter＝`type|tag|name`（AND想定）。見つからなければ0件
* `move{from,to,target,count}` - ゾーン間移動（`target: "self"|"top"|"any"` など最小）
* `win_if{expr}` - exprが真なら**勝利**
* `require{expr}` - 偽なら**以降不発**
* `destroy{target}` - 対象を墓地へ。フィールドなら破壊誘発を**enqueue**

## 4. カードDSL（YAML）スキーマ

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

## 5. 例カード

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

## 6. ゲームモード

* **パズル**（運排除）：初期手札/盤面固定で挑戦
* **ランダム**（運あり）：シャッフル、N回試行で成功率表示