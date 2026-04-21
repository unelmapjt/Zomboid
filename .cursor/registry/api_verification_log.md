# API Verification Log — NOX: EVOLVED (B42)

> 本ファイルは、API・挙動の**検証経緯と根拠**を記録する。
> 「なぜ確認済みと言えるか」のトレーサビリティを保持する。
> API 定義の一覧は `api_whitelist.md` を参照せよ。

---

## 検証ログフォーマット

```
### [YYYY-MM-DD] API名 / パターン名
- 検証方法: Decomp / EXT_Mod / 実機テスト
- 証拠ソース: ファイルパス or 説明
- 結果: 成功 / 失敗
- 備考: 特記事項
```

---

## 検証済みログ

### [2026-04-15] ItemContainer.AddItem / addItem / clear
- 検証方法: Decomp + 実機テスト
- 証拠ソース: `Docs/JAVA_Docs/zombie/inventory/ItemContainer.html`
- 結果: 成功
- 備考: `AddItem` (大文字A) と `addItem` (小文字a) は別オーバーロード。混同注意。

### [2026-04-15] IsoGameCharacter.setWornItem
- 検証方法: Decomp + 実機テスト
- 証拠ソース: `Docs/JAVA_Docs/zombie/characters/IsoGameCharacter.html` L385
- 結果: 成功
- 備考: 第1引数は `ItemBodyLocation` オブジェクト必須。String を渡すと ClassCastException。

### [2026-04-15] SurvivorDesc.setForename / setSurname
- 検証方法: Decomp
- 証拠ソース: `Docs/JAVA_Docs/zombie/characters/SurvivorDesc.html` L111, L117
- 結果: 成功
- 備考: `getDescriptor()` 経由で取得後に使用。

### [2026-04-15] IsoDeadBody.new(IsoGameCharacter, boolean)
- 検証方法: Decomp + バニラコード参照
- 証拠ソース: `Tutorial/Steps.lua:1096`
- 結果: 成功
- 備考: 座標を持つZombieを先に生成し、変換する方式が正しい。`new(getCell())` は NPE クラッシュ。

### [2026-04-21] UI Rendering & Input (drawRect / drawText / onMouseDown)
- 検証方法: Decomp (E1) + Umbrella-main (E3) + EXT_Mods (E2)
- 証拠ソース: 
    - `Docs/Decomp/zombie/ui/UIElement.java`
    - `Docs/Umbrella-main/library/lua/client/ISUI/ISUIElement.lua`
    - `Docs/EXT_Mods/3403180543/.../BWOChatWindow.lua`
- 結果: 成功
- 備考: B42 においても `ISUIElement` の主要ドロー・イベントメソッドは維持されている。解像度取得は `getPlayerScreenWidth(player)` が確実。

### [2026-04-21] UI Dynamic Scaling (getScreenHeight / MeasureStringX)
- 検証方法: EXT_Mods (E2) + Vanilla
- 証拠ソース: `BanditSettingsMain.lua` 等で動的な座標・幅計算に使用されている。
- 結果: 成功
- 備考: 4K などの高解像度対応には、1080p を基準とした `scale = screenHeight / 1080` を係数として適用するのがバニラ MOD の標準パターンである。

### [2026-04-21] NE_ViralStressHUD.lua（変異度 HUD）
- 検証方法: コード実装のみ（本リポジトリ環境では Project Zomboid 実機起動による表示確認は未実施）
- 証拠ソース: `api_whitelist.md` [UIElement / ISUIElement] の `drawRect` / `drawText` / `drawTextureScaled` / `setX` / `setY` / `getMouseX` / `getMouseY`、`getPlayerScreenHeight(player)`；クラス構造は `Docs/Umbrella-main/.../ISPanel.lua` メタ定義
- 結果: 実装済み（実機での HUD 表示・ドラッグ挙動は未検証）
- 備考:
  - 初期座標: `x=20`, `y=getPlayerScreenHeight(0)-60`。登録は `Events.OnGameStart`（リポジトリ内に `Events.OnCreateUI` の参照が無かったため「適切なタイミング」として採用）。
  - アイコンは `getTexture`（ホワイトリスト外。同一モッド `NE_IntroText.lua` と同様のグローバル利用）で `ICON_TEXTURE_PATH` を解決し、失敗時は `Missing Icon` テキスト。
  - `ISPanel` / `require "ISUI/ISPanel"` / `addToUIManager` / `UIFont.Small` はレジストリ未掲載のため、Umbrella メタ・タスク指定に従う。実機確認後にホワイトリストへ追記を推奨。
