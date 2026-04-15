-- NOX: EVOLVED Debug Menu (Client Side)
NE = NE or {}
NE.Debug = NE.Debug or {}

--- 変異度を強制設定するデバッグ関数
---@param player IsoPlayer
---@param value number 変異度(0-100)
function NE.Debug.SetMutation(player, value)
    local modData = player:getModData()
    modData.NE_MutationLevel = value
    player:Say("[NE] Mutation=" .. tostring(value) .. "%")
end

--- コンテキストメニューの構築
local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "BuildMenu:START", "DEBUG")
    end

    local ok, err = pcall(function()
        -- [A-1] メインオプション生成
        -- バニラ DebugContextMenu.lua:49-51 の正式パターン:
        --   option = parent:addOption(...)
        --   sub    = ISContextMenu:getNew(parent)
        --   parent:addSubMenu(option, sub)   ← > 矢印を表示するのはこのメソッド
        local mainOption = context:addOption("[Debug] NOX: EVOLVED", worldobjects, nil)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "A1:addOption:OK", "DEBUG")

        -- [A-2] サブメニュー生成
        local subMenu = ISContextMenu:getNew(context)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "A2:getNew:OK|sub=" .. tostring(subMenu ~= nil), "DEBUG")

        -- [A-3] サブメニュー紐付け (addSubMenu = > 矢印を表示する正式メソッド)
        context:addSubMenu(mainOption, subMenu)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "A3:addSubMenu:OK", "DEBUG")

        -- [B] 変異度操作
        local mutOption  = subMenu:addOption("Set Mutation Level...", worldobjects, nil)
        local mutSubMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(mutOption, mutSubMenu)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "B:MutSubMenu:OK", "DEBUG")

        mutSubMenu:addOption("0% (Clean)",     player, NE.Debug.SetMutation, 0)
        mutSubMenu:addOption("25% (Mild)",     player, NE.Debug.SetMutation, 25)
        mutSubMenu:addOption("50% (Danger)",   player, NE.Debug.SetMutation, 50)
        mutSubMenu:addOption("75% (Critical)", player, NE.Debug.SetMutation, 75)
        mutSubMenu:addOption("100% (Max)",     player, NE.Debug.SetMutation, 100)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "B:MutItems:OK", "DEBUG")

        -- [C] 生存日数操作
        local dayOption  = subMenu:addOption("Set Survival Days...", worldobjects, nil)
        local daySubMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(dayOption, daySubMenu)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "C:DaySubMenu:OK", "DEBUG")

        daySubMenu:addOption("Day 1",  player, NE.Debug.SetSurvivalDays, 1)
        daySubMenu:addOption("Day 7",  player, NE.Debug.SetSurvivalDays, 7)
        daySubMenu:addOption("Day 14", player, NE.Debug.SetSurvivalDays, 14)
        daySubMenu:addOption("Day 25", player, NE.Debug.SetSurvivalDays, 25)
        daySubMenu:addOption("Day 50", player, NE.Debug.SetSurvivalDays, 50)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "C:DayItems:OK", "DEBUG")

        -- [D] テレポート
        local tpOption  = subMenu:addOption("Teleport to Hotspot...", worldobjects, nil)
        local tpSubMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(tpOption, tpSubMenu)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "D:TpSubMenu:OK", "DEBUG")

        tpSubMenu:addOption("Start Scene (救護所)", player, NE.Debug.Teleport, 15640, 3909,  0)
        tpSubMenu:addOption("Military Base B17",     player, NE.Debug.Teleport, 5569,  12432, 0)
        tpSubMenu:addOption("Louisville Gate",       player, NE.Debug.Teleport, 13500, 2800,  0)
        tpSubMenu:addOption("Safe Area (Reset)",     player, NE.Debug.Teleport, 8250,  11750, 0)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "D:TpItems:OK", "DEBUG")

        -- [E] スタートシーン強制再実行 / マスク破壊 / カードキー付与
        subMenu:addOption("Force Start Scene",   player, NE.Debug.ForceStartScene)
        subMenu:addOption("Break Equipped Mask", player, NE.Debug.BreakMask)
        subMenu:addOption("Give B17 Card Key",   player, NE.Debug.GiveCardKey)
        Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "E:DONE", "DEBUG")
    end)

    if not ok then
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_DEBUG", "ContextMenu", "BuildMenu:ERR:" .. tostring(err), "WARN")
        end
    end
end

--- 装備中のマスクを破壊する
function NE.Debug.BreakMask(player)
    local wornItems = player:getWornItems()
    if not wornItems then return end
    
    local found = false
    for i = 0, wornItems:size() - 1 do
        local wi = wornItems:get(i)
        if wi then
            local item = wi:getItem()
            if item and (item:getBodyLocation() == "Mask" or item:getBodyLocation() == "FullHat") then
                item:setCondition(0)
                found = true
                break
            end
        end
    end
    
    player:Say(found and "[NE] Mask broken" or "[NE] No mask equipped")
end

--- テレポート用デバッグ関数
--- B42 確認済み: DebugContextMenu.lua:1175 → player:teleportTo(x, y, z)
function NE.Debug.Teleport(player, x, y, z)
    player:teleportTo(x, y, z)
    player:Say("[NE] TP->(" .. x .. "," .. y .. "," .. z .. ")")
end

--- 生存日数を強制設定するデバッグ関数
---@param player IsoPlayer
---@param value integer 日数
function NE.Debug.SetSurvivalDays(player, value)
    local modData = getGameTime():getModData()
    modData.NE_SurvivalDays = value
    -- タイルキャッシュを無効化して次回のゾーン計算を強制
    NE._cacheX = -1
    player:Say("[NE] SurvivalDay=" .. tostring(value))
end

--- B17_AccessKey を自分のインベントリに直接付与するデバッグ関数
--- アイテム定義が正しく機能しているかを確認するために使用
--- JAVA_Docs 確認: IsoGameCharacter.Say(String) が正規シグネチャ
---@param player IsoPlayer
function NE.Debug.GiveCardKey(player)
    -- fail-fast: pcall なし。Java 例外はスタックトレースごと surface させる
    local inv = player:getInventory()
    if not inv then
        player:Say("[NE] ERR: getInventory() nil")
        return
    end
    -- AddItem(String) ← Javadoc ItemContainer line 125 (大文字 A)
    if not inv.AddItem then
        player:Say("[NE] ERR: inv.AddItem not found|type=" .. type(inv.AddItem))
        return
    end
    local item = inv:AddItem("NOX_EVO_B42.B17_AccessKey")
    if item then
        Z_TRACER.EmitTrace("NE_DEBUG", "GiveCardKey", "OK|type=" .. tostring(item:getType()), "INFO")
        player:Say("B17 Access Key を入手した。")
    else
        Z_TRACER.EmitTrace("NE_DEBUG", "GiveCardKey", "FAILED:item=nil", "ERROR")
        player:Say("...キーが見つからない。定義ファイルを確認してください。")
    end
end

--- スタートシーンを強制再実行するデバッグ関数
--- NE_StartScene.lua の ForceRun を呼ぶ
---@param player IsoPlayer
function NE.Debug.ForceStartScene(player)
    local modData = player:getModData()
    modData.NE_StartSceneFinished = nil  -- ガードフラグをリセット
    if NE.StartScene and NE.StartScene.ForceRun then
        NE.StartScene.ForceRun(player)
    else
        player:Say("[NE] NE_StartScene not loaded")
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "DebugMenu", "Load:OK", "INFO")
end
