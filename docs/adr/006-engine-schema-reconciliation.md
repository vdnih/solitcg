# ADR-006: 仕様と実装の乖離を裁定し、エンジンのデータスキーマを確定する

## Status
Accepted

## Date
2026-09-06

## Context

カードコンテンツを AI で量産する準備として `docs/` と `lib/` を突き合わせたところ、
仕様書が「存在しないゲーム」を半分記述していることが判明した。具体的には:

- **`stats`（atk/def/hp）が完全なデッドスキーマ**: `lib/` で atk/def/hp を読んでいるのは
  パース処理・データモデル・UI 表示（`lib/ui/screens/deck_builder_screen.dart`、
  `lib/ui/widgets/card_detail_panel.dart`、`lib/presentation/components/card_component.dart`）
  のみで、ゲームロジックは一切読まない。`modify_stat` op も実装されておらず、式評価子にも
  stats の参照子が無いため、`docs/GAME_RULES.md` が謳う「hp ≤ 0 で破壊」は原理的に発火し得ない。
- **カードタイプ8種のうち4種（ritual / arcane / equip / relic）が挙動差ゼロ**: `lib/` での出現は
  文字列パース、UI の色分け（`lib/ui/theme/game_theme.dart` 等）、
  `lib/data/repositories/deck_repository.dart` で基本タイプと同グループに束ねる処理のみ。
  該当するカードは `assets/cards/` に0枚。`equip` はそのグルーピングからも漏れている。
- **勝利条件3種のうち2種が到達不能**: `docs/GAME_RULES.md` はライフ勝利・デッキ勝利・効果勝利を
  謳うが、ライフを増減する op が存在せず、ターンも未実装（→ PDR-001）なためデッキ切れ判定も
  走らない。実際に動くのは `win` / `win_if` の2 op のみ。
- **ターゲット記法がほぼ未実装**: `docs/CARD_YAML_SPEC.md` §8 の
  `"{scope}:{owner}:{selector}"` 記法のうち、実際に解釈されるのは `destroy` の
  `choose:*:<type>` のみ。`discard` は `target` フィールドを読まない。`filter` パラメータと
  機能が重複している。
- **カードID命名規則の type プレフィックスが無意味**: `docs/CARD_YAML_SPEC.md` §1.1 は
  `<type3文字>_<name>_<連番3桁>` を推奨するが、`lib/data/repositories/card_repository.dart` は
  `type:` フィールドからのみ型を取得しており、id のプレフィックスを解釈するコードは存在しない。
  `type:` フィールドとの二重管理になっている上、本 ADR での型統合（後述）でプレフィックスと
  実際の型が食い違うカードが生まれる。
- 実害として、`assets/cards/mon_crystal_looters_001.yaml` の `when: onPlay`（snake_case 違反）が
  パース時に黙って `null` を返しアビリティごと破棄されており、召喚制限が効いていなかった。

このまま検証テストを先に書くと、上記の逸脱が「正しい仕様」としてテストに固定され、負債になる。
そのため実装より先に、どちらの状態を正とするか一つずつ裁定する。

## Decision

判断基準は**可逆性**（UI やデータモデルに既に跳ねていて後から追加しにくいものは残す。
カードや処理の話で後から追加できるものは削る）とした。

| 対象 | 裁定 | 理由 |
|---|---|---|
| `stats`（atk/def/hp） | **残し、実装する**（`modify_stat` を追加） | UI に既に組み込まれ後付けが困難 |
| ライフ | **残し、実装する**（増減 op を追加） | HUD に既に組み込まれ後付けが困難 |
| エクストラデッキ（`Zone.extra` / `DeckValidator`） | **ゾーンとして残す** | 同上。埋める型の追加は別途 |
| 除外（banish）ゾーン | **ゾーンだけ追加する** | ゾーンは UI に跨るため先に用意し、使う op は後回し |
| ritual / arcane / relic / equip | **削除**し `monster / spell / artifact / domain` の4タイプに統合 | 挙動差ゼロでカード0枚。型は後から追加できる |
| ターゲット記法（`{scope}:{owner}:{selector}`） | **削除**し `filter` パラメータに一本化 | 処理の話で後から追加できる。`filter` と重複 |
| カードID命名規則の type プレフィックス | **要求を廃止**。`id` はスネークケースで一意、連番3桁は同名バリエーションがある場合のみ任意 | プレフィックスを解釈するコードが無く `type:` の二重管理。型統合でプレフィックスが実態と食い違う懸念もある。この規則なら既存20枚すべてが適合し例外リストが不要 |
| 勝利条件（ライフ勝利・デッキ勝利） | **到達可能にする**（ライフ op とターン終了判定の追加により） | PDR-001 のターンモデルと合わせて成立させる |
| `activated` の「1ターンに1度」制限 | **「1ゲームに1度」が正しい仕様**（PDR-001 のターンモデルによる） | リセット処理を新設する必要が無くなる |

## 検討したが採らなかった案

- **仕様書どおりに実装を拡張する**（8タイプ・ターゲット記法・戦闘を作り込む）:
  作業量に対してこのプロダクトの体験の核（コンボ連鎖・ソリティア純粋性）への寄与が薄いため見送り。
- **カードID命名規則をそのまま維持し、違反する既存7枚を例外リスト化する**:
  例外リストは守れない規則を追認するだけで、新規カード追加のたびに例外を増やすリスクがある。
  プレフィックス自体が無意味だったため、規則側を撤廃する方を採った。

## 影響範囲

- `docs/SPEC.md` / `docs/GAME_RULES.md` / `docs/CARD_YAML_SPEC.md`: 本 ADR の裁定に沿って書き直す
- `docs/PRD.md`: カードプール拡充のステータス記述を実態に合わせる
- 実装（`lib/domain/models/card_data.dart` の `CardType` enum、`OperationExecutor`、
  `Zone` enum、UI の色分けロジック等）は本 ADR ではまだ変更しない。後続 Issue で行う
  （4タイプ統合、`modify_stat` 実装、ライフ op 追加、除外ゾーン追加、ターゲット記法削除、
  パーサ厳格化）
- `assets/cards/*.yaml`: 型統合（E-1 相当）実施時に ritual/arcane/relic/equip を使うカードが
  無いことを確認済みなので、既存カードへの影響は無い
