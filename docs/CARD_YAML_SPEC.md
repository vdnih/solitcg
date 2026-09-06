# docs/CARD_YAML_SPEC.md（v0.7.0）

この文書は、**SoliTCG** の **カード定義ファイル（YAML）** の仕様です。
エンジンはこの形式の YAML を読み込み、カードの挙動を決定します。

> v0.7.0 での主な変更点（`docs/adr/006-engine-schema-reconciliation.md` の裁定に基づく）:
> カードタイプを4種に統合、ターゲット記法を廃止し `filter` に一本化、
> カードID命名規則から type プレフィックスの要求を撤廃。

---

## 0. 基本ルール

* 文字コードは **UTF-8**。拡張子は **`.yaml`**。
* 1ファイル＝1枚のカード定義。
* 予約語・列挙値は **小文字** で統一。
* 不正キーや型違いは読み込み時にエラーとすることを推奨（現状はパーサが警告なしにスキップする。
  厳格化は Issue E-7 で対応予定）。

---

## 1. トップレベルスキーマ

```yaml
id: string                    # 必須。一意ID（スネークケース推奨）
name: string                  # 必須。表示名
type: monster | spell | artifact | domain   # 必須
tags: [string, ...]           # 任意。検索・相互作用用タグ
text: string                  # 必須。プレイヤー向け説明（自由記述）
version: integer              # 必須。カードデータの版番号

# monster のみ。hp 必須、atk / def は任意（効果参照用）
stats:
  atk: integer (>=0)          # 攻撃力（任意。効果の参照値として使用）
  def: integer (>=0)          # 防御力（任意。効果の参照値として使用）
  hp:  integer (>=0)          # 必須。hp <= 0 で即破壊 → on_destroy 発動
                               # ※ modify_stat op が未実装のため、現状 hp は変動しない（表示専用）

abilities:                    # 任意。0個以上
  - when: on_play | on_destroy | on_discard | activated | on_spell_played
    pre: [ "expr", ... ]      # 発動前提（すべてtrue時のみ実行）
    effect:                   # 実行ステップ（配列）
      - { op: operation_name, ...params }
      - ...
```

> `priority` フィールドは廃止。同時トリガーは発生順（エンキュー順）に自動で解決する。
> プレイヤーはキューの順序を操作できない（ADR-004）。

### 1.1 カードID命名規則

* `id` はスネークケース（英数字とアンダースコア）で、全カード中で一意にする。
* ファイル名は `<id>.yaml`。
* 連番（例: `_001`）は、同名カードのバリエーションが複数ある場合のみ任意で付ける。

> 旧規則（`<type3文字>_<name>_<連番3桁>`）は撤廃した。id のプレフィックスを解釈するコードは
> エンジンに存在せず（`type` は YAML の `type:` フィールドからのみ取得する）、
> `type:` フィールドとの二重管理になっていたため（ADR-006）。既存カードの `mon_` / `spl_` 等の
> プレフィックスは、意味を持たない名前の一部としてそのまま残っている。

---

## 2. `type`ごとのルール

| type     | `stats`必須 | 備考 |
| -------- | --------- | ---- |
| monster  | 必須（hp のみ必須、atk/def は任意） | hp <= 0 で破壊（※ modify_stat 未実装のため現状は発火しない） |
| spell    | 不要 | 使い切り効果カード。プレイ後に墓地へ |
| artifact | 不要 | 永続系 |
| domain   | 不要 | 場全体に影響。同時に1枚制限 |

> 旧 `ritual` / `arcane` / `equip` / `relic` は ADR-006 により廃止した。

---

## 3. `when`（発動タイミング）

| 値 | 発火タイミング |
| --- | --- |
| `on_play` | 手札からプレイした直後（サーチ・移動では発火しない） |
| `on_destroy` | hp ≤ 0 または `destroy` op により破壊された直後 |
| `on_discard` | 手札から捨て札に置かれた直後 |
| `activated` | プレイヤーが手動で発動。`once_per_turn: true`（省略時デフォルト）でエンジンが1ゲーム1度を強制（ゲームは1ターンで完結するため「1ターン」と「1ゲーム」は同義。PDR-001）。`once_per_turn: false` で無制限。 |
| `on_spell_played` | spell がプレイされるたび（現状は domain カードのみが購読可能） |

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

* ゾーン数：`hand.count`, `deck.count`, `board.count`, `grave.count`
* ドメイン・ライフ：`domain.exists`, `player.life`, `opponent.life`
* タグ/タイプ数：`count(type:'artifact', zone:'board:self')`, `count(tag:'dragon', zone:'hand:self')`
* カード固有カウンタ：`self.counter('key')`（`add_counter`/`remove_counter` op で操作。§6.6 参照）
* 比較演算子（1式につき1つのみ）：`> >= < <= == !=`。`&&`/`||`/前置 `!` は非対応 — 複数条件の
  AND は `pre` に式を複数並べることで表現する。
* 未知の参照子は例外を握りつぶして `0` と評価される（サイレント不発）。typo に注意すること。

---

## 5. `effect`（効果ステップ）

* 配列で順次実行。
* 先頭に「消費」処理を書くのが慣習（例：破壊、移動など）。
* 効果中に `win` / `win_if` が成立した場合は即時勝利し残りは解決せず終了。

---

## 6. サポートする `op`（MVP版）

### 6.1 カード移動・破壊

```yaml
# タイプでフィルタリングしてサーチ
- { op: search, from: deck, to: hand, filter: { type: "domain" }, max: 1 }

# タグでフィルタリングして移動（複数候補 → プレイヤーが選択）
- { op: move, from: grave, to: hand, filter: { tag: "token" }, count: 1 }

# タグでフィルタリングして破壊（複数候補 → プレイヤーが選択）
- { op: destroy, target: board, filter: { tag: "weak" }, count: 1 }
```

* `from` / `to` / `target`: `hand | deck | grave | board | domain | extra`
* `count`: 対象枚数。省略時は 1。
* `filter`: タグ・タイプ・名前でカードを絞り込む（後述「タグシステム」参照）。カードを絞り込む
  手段はこの `filter` に一本化されている（§8 参照）。
* **複数候補がある場合はプレイヤーが選択 UI で選択できる**。

### 6.2 手札操作

```yaml
- { op: draw, count: 2 }
# filter なし → 先頭から count 枚を自動捨て
- { op: discard, from: hand, count: 1 }
# filter あり + 複数候補 → プレイヤーが選択
- { op: discard, from: hand, count: 1, filter: { tag: "burn" } }
```

* `discard` は `from: hand` のみ対応する（他ゾーンを指定すると failure になる）。
* `filter` を指定した場合、一致するカードが `count` 枚を超えるとプレイヤーが選択する。
* `filter` を省略した場合は先頭から `count` 枚を自動選択（従来動作）。

### 6.3 ステータス操作

```yaml
- { op: modify_stat, target: board, filter: { type: "monster" }, atk: +500, hp: -1 }
```

* **現状未実装**（Issue E-5）。`hp <= 0` で即破壊 → `on_destroy` 誘発、という挙動は
  この op が実装されて初めて成立する。

### 6.4 勝敗条件

```yaml
- { op: win }                                # 無条件勝利
- { op: win_if, expr: "hand.count == 0" }    # 条件付き勝利
- { op: lose_if, expr: "deck.count == 0" }   # 条件付き敗北
```

> `lose_if`/`win_if` の `expr` は比較演算子を1つだけ含む単一式（§4 参照）。
> `hand.count == 0 && deck.count == 0` のような複合条件は書けない。

### 6.5 ドメイン操作

```yaml
- { op: set_domain, card: "dmn_echo_hall_001" }
```

* **未実装**: `set_domain` op は常に failure を返すスタブ実装（カードDB検索ロジック未実装）。
  現状、ドメインカードは手札から直接プレイすることでのみ場に出せる
  （新ドメインの `on_play` → 旧ドメイン移送 → 旧 `on_destroy` の順で自動処理。詳細は `SPEC.md` §6）。

### 6.6 カウンター操作

```yaml
- { op: add_counter, key: "stack", amount: 1 }     # source カードの metadata[key] に加算
- { op: remove_counter, key: "stack" }             # source カードの metadata[key] を 0 にリセット
```

* `source`（トリガー発生元カード）の `metadata` に per-card のカウンターを保持する。
* `pre` 式の `self.counter('key')` で参照できる（§4 参照）。
* `key` 省略時は `'counter'` がデフォルト。`amount` 省略時は `1`。

### 6.7 その他

```yaml
- { op: require, expr: "hand.count >= 1" }
```

* 式が偽の場合、effect の実行をその場で中断する（failure）。既に実行済みの前段 effect は
  ロールバックされない点に注意。

---

## 7. タグシステム

### タグの定義

カード YAML の `tags` フィールドに任意の文字列タグを複数設定できます。

```yaml
tags: [warrior, elite, burn]
```

* タグは大文字・小文字を区別する（`'Warrior'` と `'warrior'` は別物）。
* タグ名は英数字・アンダースコア・ハイフン推奨。
* タグ数の上限はなし。

### filter パラメータ

`discard` / `move` / `destroy` / `search` の各 op は `filter` パラメータを受け付けます。
カードを絞り込む手段はこの `filter` に一本化されている（§8 参照）。

```yaml
filter:
  tag: "xxx"      # 指定タグを持つカードのみ対象
  type: "spell"   # 指定タイプのカードのみ対象（tag と同時使用可能）
  name: "カード名" # 名前完全一致（tag/type と同時使用可能）
```

* 複数条件はすべて AND。
* `filter` を省略した場合はすべてのカードが対象。

### タグによる勝利条件の例

```yaml
id: spl_daisangen
name: 大三元の魔法
type: spell
tags: [spl_daisangen]
text: 「白の魔法」「發の魔法」「中の魔法」がそれぞれ3枚以上あること。効果：勝利する。
version: 1
abilities:
  - when: on_play
    pre:
      - "count(tag:'spl_haku', zone:'hand:self') >= 3"
      - "count(tag:'spl_hatsu', zone:'hand:self') >= 3"
      - "count(tag:'spl_chun', zone:'hand:self') >= 3"
    effect:
      - { op: win }
```

### プレイヤー選択との組み合わせ例

```yaml
id: spl_purge
name: 弱者一掃
type: spell
tags: [removal]
text: 手札の「burn」タグのカードを1枚捨て、場の「weak」タグを1体破壊する。
version: 1
abilities:
  - when: on_play
    pre:
      - "count(tag:'burn', zone:'hand:self') >= 1"
      - "count(tag:'weak', zone:'board:self') >= 1"
    effect:
      # 複数候補があるとプレイヤーが選択 UI で選ぶ
      - { op: discard, from: hand, count: 1, filter: { tag: "burn" } }
      - { op: destroy, target: board, filter: { tag: "weak" }, count: 1 }
```

---

## 8. カード対象の絞り込み

対象カードを絞り込む手段は `filter` パラメータ（§6.1・§7）に一本化されている。
旧仕様にあった `"{scope}:{owner}:{selector}"` 形式のターゲット記法は、`destroy` の
`choose:*:<type>` 以外のパターンが実装されておらず、`filter` と機能が重複していたため
ADR-006 により廃止した。

---

## 9. カード例

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
id: tenshou_no_higi
name: 天象の秘儀
type: artifact
text: 自分のアーティファクト2枚を破壊してカードを5枚引く。
version: 1
abilities:
  - when: on_play
    pre:
      - "count(type:'artifact', zone:'board:self') >= 2"
    effect:
      - { op: destroy, target: board, filter: { type: "artifact" }, count: 2 }
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

### activated（1ゲーム1度）

```yaml
id: atf_crystal_001
name: クリスタルコア
type: artifact
text: 1ゲームに1度、手札を2枚捨ててカードを3枚引く。
version: 1
abilities:
  - when: activated
    pre:
      - "hand.count >= 2"
    effect:
      - { op: discard, from: hand, count: 2, selection: choose }
      - { op: draw, count: 3 }
```
