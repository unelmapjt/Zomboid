# API Whitelist — NOX: EVOLVED (B42 Confirmed)

> このファイルに記載されている API は、**実際の実行で動作確認済み**のものだけを収録する。
> 記載がない場合は `Docs/` を参照し、それでも不明な場合はユーザーに確認すること。
> **推測でコードを書くことを禁止する。**
> 検証の経緯は `.cursor/registry/api_verification_log.md` を参照せよ。

---

## [Java API] ItemContainer

> 参照: `Docs/JAVA_Docs/zombie/inventory/ItemContainer.html`

| メソッド | シグネチャ | ケーシング | 備考 |
|----------|-----------|-----------|------|
| `AddItem` | `AddItem(String fullType)` → `InventoryItem` | **大文字 A** | 文字列でアイテムを追加。戻り値はInventoryItem |
| `addItem` | `addItem(InventoryItem item)` → `InventoryItem` | 小文字 a | InventoryItemオブジェクトを追加する別オーバーロード |
| `clear` | `clear()` | **小文字 c** | コンテナを空にする |

```lua
-- ✅ 確認済み: 文字列でアイテムを追加する
local item = inv:AddItem("Base.JacketLong_Doctor")

-- ✅ 確認済み: InventoryItemオブジェクトを追加する
local item2 = inv:addItem(existingItem)
```

---

## [Java API] IsoGameCharacter

> 参照: `Docs/JAVA_Docs/zombie/characters/IsoGameCharacter.html`

| メソッド | シグネチャ | ケーシング | 参照先 |
|----------|-----------|-----------|--------|
| `Say` | `Say(String text)` | **大文字 S** | L672 |
| `getInventory` | `getInventory()` → `ItemContainer` | 小文字 g | Umbrella-main IsoGameCharacter.lua:1442 |
| `setWornItem` | `setWornItem(ItemBodyLocation, InventoryItem)` | 小文字 s | L385 |
| `getDescriptor` | `getDescriptor()` → `SurvivorDesc` | 小文字 g | L349 |

```lua
-- ✅ 確認済み: キャラクターに発言させる
zombie:Say("Hello!")

-- ✅ 確認済み: インベントリ取得
local inv = zombie:getInventory()
```

---

## [Java API] InventoryItem

> 参照: `Docs/JAVA_Docs/zombie/inventory/InventoryItem.html`

| メソッド | シグネチャ | ケーシング | 参照先 |
|----------|-----------|-----------|--------|
| `getBodyLocation` | `getBodyLocation()` → `ItemBodyLocation` | 小文字 g | L516 |

---

## [Java API] SurvivorDesc

> 参照: `Docs/JAVA_Docs/zombie/characters/SurvivorDesc.html`

| メソッド | シグネチャ | ケーシング | 参照先 |
|----------|-----------|-----------|--------|
| `setForename` | `setForename(String)` | 小文字 s | L111 |
| `setSurname` | `setSurname(String)` | 小文字 s | L117 |

```lua
-- ✅ 確認済み: キャラクター名設定パターン
local desc = zombie:getDescriptor()
if desc then
    desc:setForename("Dr.")
    desc:setSurname("Hiro")
end
```

---

## [パターン] Worn Item 手動装着

```lua
-- ✅ 確認済み正規パターン
local jacket = inv:AddItem("Base.JacketLong_Doctor")
if jacket then
    zombie:setWornItem(jacket:getBodyLocation(), jacket)
end

-- ❌ 禁止: setWornItemの第1引数にStringを渡す
zombie:setWornItem("BodyTop", jacket)  -- ClassCastException
```

---

## [パターン] Events.OnTick 安全なリスナー除去

```lua
-- ✅ 確認済み: 危険なコード実行の直前にRemove
local function onTick()
    if not chunkLoaded() then return end
    Events.OnTick.Remove(onTick)   -- ← スポーン前に除去（無限増殖防止）
    createZombie(...)
end

-- ❌ 禁止: 条件の中でRemove（例外発生時にスキップされる）
local function onTick()
    if spawnDrHiro() then
        Events.OnTick.Remove(onTick)
    end
end
```

---

## [B42] アイテム定義 正規構文

```txt
-- ✅ B42 確認済み正規形式
item MyItem
{
    ItemType = base:normal,
    ...
}

-- ❌ 禁止: B41旧構文（RuntimeExceptionをスロー）
item MyItem
{
    Type = Normal,
    ...
}

-- ❌ 禁止: カスタムモジュールでのimports
imports { Base }
```

---

## [Java API] UIElement / ISUIElement
> 参照: `Docs/Decomp/zombie/ui/UIElement.java`
> 参照: `Docs/Umbrella-main/library/lua/client/ISUI/ISUIElement.lua`

| メソッド | シグネチャ | 備考 |
|----------|-----------|------|
| `drawRect` | `drawRect(x, y, w, h, a, r, g, b)` | 背景・バーの描画。色は0.0-1.0 |
| `drawText` | `drawText(str, x, y, r, g, b, a, font)` | テキスト描画。fontはUIFont定数 |
| `drawTextureScaled` | `drawTextureScaled(tex, x, y, w, h, a, r, g, b)` | アイコン等の描画 |
| `setX` / `setY` | `setX(x)`, `setY(y)` | 座標の更新（ドラッグ等に使用） |
| `getMouseX` / `getMouseY` | `getMouseX()`, `getMouseY()` | 要素内マウス座標の取得 |
| `MeasureStringX` | `getTextManager():MeasureStringX(UIFont, String)` | 文字列のピクセル幅を取得 |

## [Global API] Screen / Core
| メソッド | シグネチャ | 備考 |
|----------|-----------|------|
| `getPlayerScreenWidth` | `getPlayerScreenWidth(player)` | 解像度（幅）取得 |
| `getPlayerScreenHeight` | `getPlayerScreenHeight(player)` | 解像度（高さ）取得 |
| `getScreenHeight` | `getCore():getScreenHeight()` | 画面の物理的な高さ（ピクセル）を取得 |

```lua
-- ✅ 確認済み: 画面左下の座標計算
local x = 10
local y = getPlayerScreenHeight(player) - 100
```

---

## ✏️ 更新ルール

- 実装が動作確認されたら、使用したAPI・パターンをこのファイルに追記する
- 既存の記載を削除・上書きしない（追記のみ）
- 検証経緯は必ず `api_verification_log.md` に記録する
