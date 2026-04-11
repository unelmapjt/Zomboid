-- NOX: EVOLVED Debug Menu (Client Side)
NE = NE or {}
NE.Debug = NE.Debug or {}

--- 汚染度を強制設定するデバッグ関数
---@param player IsoPlayer
---@param value number 汚染度(0-100)
function NE.Debug.SetPollution(player, value)
    local modData = player:getModData()
    modData.NE_PollutionLevel = value
    player:say("Debug: Pollution Level Set to " .. tostring(value) .. "%")
end

--- コンテキストメニューの構築
local function OnFillWorldObjectContextMenu(playerNum, context, worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- メインメニュー
    local mainOption = context:addOption("[Debug] NOX: EVOLVED", worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:setSubMenu(mainOption, subMenu)

    -- 1.3.2: 汚染度操作サブメニュー
    local pollOption = subMenu:addOption("Set Pollution Level...", worldobjects, nil)
    local pollSubMenu = subMenu:getNew(subMenu)
    subMenu:setSubMenu(pollOption, pollSubMenu)

    pollSubMenu:addOption("0% (Clean)", player, NE.Debug.SetPollution, 0)
    pollSubMenu:addOption("25% (Mild)", player, NE.Debug.SetPollution, 25)
    pollSubMenu:addOption("50% (Sickness)", player, NE.Debug.SetPollution, 50)
    pollSubMenu:addOption("75% (Critical)", player, NE.Debug.SetPollution, 75)
    pollSubMenu:addOption("100% (Evolution)", player, NE.Debug.SetPollution, 100)
    
    -- 1.3.3: 生存日数操作サブメニュー
    local dayOption = subMenu:addOption("Set Survival Days...", worldobjects, nil)
    local daySubMenu = subMenu:getNew(subMenu)
    subMenu:setSubMenu(dayOption, daySubMenu)
    
    daySubMenu:addOption("Day 1 (Initial)", player, NE.Debug.SetSurvivalDays, 1)
    daySubMenu:addOption("Day 7 (Week 1)", player, NE.Debug.SetSurvivalDays, 7)
    daySubMenu:addOption("Day 14 (Week 2)", player, NE.Debug.SetSurvivalDays, 14)
    daySubMenu:addOption("Day 25 (Convergence)", player, NE.Debug.SetSurvivalDays, 25)
    daySubMenu:addOption("Day 50 (End Game)", player, NE.Debug.SetSurvivalDays, 50)

    -- 1.3.4: テレポート操作サブメニュー
    local tpOption = subMenu:addOption("Teleport to Hotspot...", worldobjects, nil)
    local tpSubMenu = subMenu:getNew(subMenu)
    subMenu:setSubMenu(tpOption, tpSubMenu)
    
    tpSubMenu:addOption("Secret Military Base (Tier 1)", player, NE.Debug.Teleport, 5569, 12432, 0)
    tpSubMenu:addOption("Louisville Checkpoint (Tier 1)", player, NE.Debug.Teleport, 11786, 9253, 0)
    tpSubMenu:addOption("Rosewood Clinic (Standard)", player, NE.Debug.Teleport, 8161, 11340, 0)
    tpSubMenu:addOption("Reset to Safe Area", player, NE.Debug.Teleport, 8250, 11750, 0)

    -- 1.3.5: マスク操作
    subMenu:addOption("Break Equipped Mask", player, NE.Debug.BreakMask)
end

--- 装備中のマスクを破壊する
function NE.Debug.BreakMask(player)
    local wornItems = player:getWornItems()
    if not wornItems then return end
    
    local found = false
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:get(i):getItem()
        if item:getBodyLocation() == "Mask" or item:getBodyLocation() == "FullHat" then
            item:setCondition(0)
            player:say("Debug: Mask Broken (Condition 0)")
            found = true
            break
        end
    end
    
    if not found then
        player:say("Debug: No mask equipped to break.")
    end
end

--- テレポート用デバッグ関数
function NE.Debug.Teleport(player, x, y, z)
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    player:setLx(x)
    player:setLy(y)
    player:setLz(z)
    player:say("Debug: Teleported to specific location.")
end

--- 生存日数を強制設定するデバッグ関数
---@param player IsoPlayer
---@param value integer 日数
function NE.Debug.SetSurvivalDays(player, value)
    local modData = getGameTime():getModData()
    modData.NE_SurvivalDays = value
    player:say("Debug: Survival Days Set to Day " .. tostring(value))
end

-- イベント登録
Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)

print("NOX: EVOLVED - Client: NE_DebugMenu ロード完了。")
