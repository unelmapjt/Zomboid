# Active Context: NOX_EVO_B42

最終更新: 2026-04-15（FBORenderCell 修正）

---

## 1. 現在の実装状況

### 完了済み (実装のみ・検証未完)
- **Z-System**: `Z_Core.lua` / `Z_Tracer.lua` デプロイ完了。`TRACE_LEVEL=DEBUG` で稼働中。
- **NE_Core.lua**: `NE.Config` 全定数集約（BaseRate/LocMult/MaskMult/ZoneThresholds/ZoneMultipliers/Hotspots 25箇所）。`NE.GetZoneMultiplier()` 離散5段階ゾーン実装。`NE.GetPhaseMult()` Phase 1/2/3 遷移実装。タイルキャッシュ実装。
- **NE_Mutation.lua**: `DeltaMutation = BaseRate × LocMult × MaskMult × PhaseMult × FogMult × ZoneMultiplier` 全係数実装。毎分 `NE_MUTATION` トレース出力。
- **NE_WorldManager.lua**: `NE_SurvivalDays` / `NE_Phase` 更新、フェーズ遷移時 `NE_PhaseShiftTrigger` 発火。
- **NE_PlayerManager.lua**: クライアント側 heartbeat / `NE.UpdateMutation` 呼び出し。
- **NE_StartScene.lua**: `OnCreatePlayer` トリガー（B42: `OnCharacterCreationFinished` は存在しない）。装備剥奪・初期アイテム支給・Dr.Hiro 遺体生成（pcall 保護）・ISModalDialog 5ページ演出（pcall + say フォールバック）。
- **NE_DebugMenu.lua**: `option.subMenu = subMenu`（B42 正式パターン）でサブメニュー修正済み。Set Mutation Level / Set Survival Days / Teleport / Force Start Scene / Break Equipped Mask。

### 検証状況
- `NE_HEARTBEAT` / `NE_MUTATION` トレース: ✅ 出力確認済み
- デバッグメニュー展開: 🔄 修正済み・再起動後の検証待ち
- スタートシーン発火: 🔄 B42 API エラー修正後・再起動の検証待ち
- Zone / Loc / Phase 値の正確性: ❌ 未検証（ホットスポット圏外で Zone:0.00 のまま）

---

## 2. B42 確定事項（Ground Truth から得た知見）

### B42 アイテム定義の必須項目
- `Type = Normal` は **B41 構文**。B42 では `getItemType()` が null を返しクラッシュ。
- B42 正しい構文: `ItemType = base:key` / `ItemType = base:normal` / `ItemType = base:drainable` など namespace 形式。
- `DisplayCategory = Security` は B42 の key 系アイテムで有効（vanilla `generated/items/key.txt` 確認済）。
- アイコン指定: `Icon = Key_Blank` など vanilla に実在するアイコン名を使うこと。
- 根拠ファイル: `C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\scripts\generated\items\key.txt`

### ゾンビ/遺体生成（B42 確定パターン）
- **正しいパターン**: `createZombie(x,y,z)` → `zombie:DoZombieInventory()` → `zombie:getInventory():AddItem(...)` → `IsoDeadBody.new(zombie, false)`
  - 根拠: Umbrella-main `__global.lua:621` / `IsoZombie.lua` / バニラ `Tutorial/Steps.lua:1088-1096`
- **`IsoDeadBody.new(cell)`（1引数版）は絶対禁止**: 座標のない遺体を生成 → `FBORenderCell.renderInternal> Exception thrown` が毎フレーム発生する
- **`IsoGridSquare.addCorpse`**: Umbrella-main `IsoGridSquare.lua` に存在しない（Lua 非露出）。使用禁止。
- **`IsoDeadBody.getInventory()`**: `IsoDeadBody` は `IsoGameCharacter` を継承しないため Lua 非露出。使用禁止。
- **正しいインベントリ操作**: `zombie:getInventory():AddItem(...)` を `IsoDeadBody.new(zombie, false)` の**前**に実行する。
- Kahlua 制約: `body.square = sq` のような Java フィールドへの直接 SET は `tableSet` エラーになる。必ずメソッド経由で操作すること。

---

## 3. 既知の技術的負債

| ID | 内容 | 優先度 |
|---|---|---|
| TechDebt-01 | `OnCreatePlayer` はロード時も発火。スタートシーン未実行セーブのロードで誤発火リスク | Phase X.2 で対応 |
| TechDebt-02 | `cam:setZoom()` / `gt:setMultiplier()` — B42 API 未確認のため一時削除。シネマティック演出が省略されている | 確認後に復元 |
| TechDebt-03 | ~~`IsoDeadBody(IsoCell)` の `getInventory()` が nil~~  → **解決済み**: `createZombie` + `IsoDeadBody.new(zombie, false)` パターンに移行。アクセスカードはゾンビのインベントリに付与してから変換する | ✅ 解決 |
| TechDebt-04 | 翻訳キー `UI_NE_Confirm` / `UI_NE_Next` 未定義。暫定ハードコード中 | Phase X.3 で対応 |
| TechDebt-05 | `NE_PhaseShiftTrigger` を消費するリスナー未実装 | Phase 11.3 で対応 |

---

## 4. 次の優先作業

1. **ゲーム再起動 → 新規ゲーム作成** でスタートシーン発火を確認
   - `FBORenderCell` エラーが消えていること（最重要）
   - `NE_SCENE:DrHiro:Spawn:OK` トレースが出ること
   - Dr.Hiro の遺体が HIRO_X(15640), HIRO_Y(3910) 付近に出現すること
   - 遺体を調べて B17_AccessCardKey が入っていること
   - `NE_SCENE:StartScene:Run:OK` トレースが出ること
2. **ホットスポットへテレポート** して `Zone:2.00` / `Delta:1.5` を確認（Louisville Gate で Day 10）
3. **Phase 2 検証**: `Set Survival Days → Day 25` で `Phase:1.5` になることを確認
4. 検証完了後、ROADMAP の `[ ] 検証` チェックを埋める
5. Phase 5（閾値バーキング・HUD・症状）へ進む

---

## 5. 開発ルール参照

| 作業種別 | 従うルール |
|---|---|
| バグ修正・クラッシュ対応 | `.cursorrules`（Z-System）— 最小 DIFF |
| 新機能実装・定数変更 | `.cursor/rules/nox-evo-dev-principles.mdc`（開発原則）— 設計書絶対視 |
