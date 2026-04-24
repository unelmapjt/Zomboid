# NOX: EVOLVED 開発セッションログ — 2026-04-25

**ブランチ**: `diagnostic-limp-pain-check`
**コミット**: `変異度コンティニュー` (2732b85a)

---

## 1. 変異度コンティニューリセット問題【解決済み】

### 根本原因
`media/lua/client/LastStand/NE_HyperErosion.lua` の `challenge.OnCreatePlayer` が、コンティニュー（ロード）時にも無条件で `NE_MutationLevel = 20.0` を代入していた。

`NE_StartScene.lua` / `NE_Config.lua` / `NE_Mutation.lua` に施した多数のガードをすり抜けて、チャレンジ登録ルートから上書きが発生していた。

### 修正内容
**`NE_HyperErosion.lua:91-104`** — `challenge.OnCreatePlayer` に生存時間ガードを追加。

```lua
local survived = player:getHoursSurvived() or 0
if survived > 0.001 then
    return  -- コンティニュー：セーブ済み変異度を保護
end
player:getModData().NE_MutationLevel = 20.0  -- 新規のみ
```

### 教訓
- 「`NE_MutationLevel = 20` を書いているファイルはどれか？」を **最初に `grep` で全ファイル検索すべきだった**。
- `LastStand/` 以下のファイルはすべてのガードロジックから独立したイベントルートを持つため、変更時は必ず確認が必要。

---

## 2. `NE.SyncEvolvedMovementLockGlobally` 冪等性対応【実装済み】

### 変更内容
フラグ管理（`NE_EvolvedMovementLockSubscribed`）を廃止し、毎回 `Remove → Add` する冪等性アーキテクチャに変更。

```lua
Events.OnTick.Remove(NE_MutationEvolvedMovementLock)
if need then
    Events.OnTick.Add(NE_MutationEvolvedMovementLock)
end
```

- **理由**: Lua VM 再起動でフラグは揮発するが、OnTick リスナーも同時に消滅する。よって「フラグを信頼せず、毎回条件から再構築する」設計が最も堅牢。
- **参考**: React などのモダン UI と同様の「状態ではなく条件から再構築する」思想。

---

## 3. スタミナ制限の段階化【実装済み・MDD更新済み】

| 変異度 | スタミナ上限 | 移動制限 |
|---|---|---|
| 0〜49% | 制限なし | 制限なし |
| 50〜74% | **0.5** | Sprint 禁止 |
| 75〜99% | **0.25** | Run 禁止 |
| 100% | **0（固定）** | 全速度禁止 |

`CharacterStat.ENDURANCE` を B42 ネイティブ方式（`stats:set(CS.ENDURANCE, value)`）で制御。

---

## 4. 低変異度（25%未満）のデバフ抑制【実装済み】

### 問題
`moodVal` の計算式が `mutation < 25` の時も線形にパニック・酔いを付与していたため、20% でも **Tipsy / Nervous** が発生していた。

### 修正（`NE_PlayerManager.lua:450-453`）
```lua
-- 修正後: 25%未満はデバフゼロ
if mutation < 25 then
    moodVal = 0
elseif mutation < 50 then
    moodVal = 15 + (mutation - 25) * (15 / 25)
...
```

---

## 5. 薬アイテムの B42 対応【実装済み】

### 問題
`ItemType = Food` への変更により「飲む」の右クリックメニューが消えた。

### 解決（KnoxDrugs E2 実証済みパターン）
- `ItemType = base:drainable` に戻す。
- `OnEat = NE_OnEatAntiMutantDrug` をスクリプト定義に追加（KnoxDrugs 方式）。
- Lua 側でグローバル関数 `NE_OnEatAntiMutantDrug(food, character, percent)` を定義。
- `Events.OnEatFood` は**廃止**（B42 では機能しない）。
- ファイルを `client/` → `shared/` に移動（KnoxDrugs と同様）。

---

## 6. 翻訳ファイルへの日本語移行【実装済み】

日本語文字列を Lua 内にハードコードすると文字化けするため、翻訳ファイルに移行。

**`media/lua/shared/Translate/JP/IG_UI.json`** に以下を追加：
```json
"IGUI_NE_Antimutagen_Success": "……効いている。変異度が %1 下がった。",
"IGUI_NE_Retardant_Success": "……変異の進行が 30 分間停止した。"
```

Lua 側: `character:Say(getText("IGUI_NE_Antimutagen_Success", math.floor(sub)))`

---

## 7. 抗変異薬（NE_AntiMutantDrug）副作用の最終仕様

### 最終決定仕様
| 効果 | 内容 |
|---|---|
| **変異度減少** | 40〜60% をランダムで即座に減少（`ZombRand(21) + 40`） |
| **吐き気** | `FOOD_SICKNESS` に 30〜50 を**加算**（KnoxDrugs 実証済み方式）|
| **パニック** | `PANIC = 0.95` に設定 |
| **HP減少** | **なし**（吐き気のみで表現） |
| **副作用持続** | `NE_DrugSideEffectEndTime` で 10 分間 `FOOD_SICKNESS` 上書きを保護 |

> [!NOTE]
> `FOOD_SICKNESS` を固定値 60 にセットするのではなく、現在値に **30〜50 加算する**方式（KnoxDrugs準拠）とした。これにより飲み重ねによる段階的悪化が可能になる。

---

## 8. 汚染遅延剤（NE_Retardant）仕様

| 効果 | 内容 |
|---|---|
| **変異上昇の阻止** | 効果中は `delta > 0` を `0` に固定（汚染地帯でも進行しない） |
| **自然回復の許可** | `delta < 0`（安全圏での浄化）はそのまま通過する |
| **持続時間** | ゲーム内 30 分（`modData.NE_RetardantEndTime = now + 30.0`） |
| **HUD表示** | 効果中: 青色タイマー `[VIRAL RETARDANT: MM:SS]` + 鍵アイコン |

---

## 9. 本日の教訓まとめ

1. **バグ調査は `grep` から**: 問題の変数（`NE_MutationLevel = 20`）を全ファイルで検索することで即座に犯人ファイルを特定できる。推測でコードを書き換え続けることを避ける。
2. **B42 での薬の正解**: `ItemType = base:drainable` + `OnEat = [グローバル関数名]` (KnoxDrugs方式)。`Events.OnEatFood` は廃止。
3. **BodyDamage の Authority**: B42 では `setHealth/ReduceHealth/setOverallBodyHealth` は Authority を持たない可能性がある（Rule-G2）。ダメージは `CharacterStat` 経由または `BodyPart:AddDamage()` が実証済み。
4. **症状の上書き衝突**: `MutationSymptomUpdate` が毎分 Stats を書き換えるため、薬の副作用は `modData` にタイマーを保存して保護する必要がある。
5. **冪等性設計**: 「フラグで状態管理」ではなく「毎回 Remove→Add で条件から再構築」する設計が Zomboid の不安定な Lua VM 環境で最も安全。
