-- NE_PlayerManager.lua: Syntax OK check (remove after verify)
-- --------------------------------------------------------------------------
-- Path: media/lua/client/NE_PlayerManager.lua
-- Role: プレイヤー単位の生存ロジックの管理 (クライアント側)
-- --------------------------------------------------------------------------

NE = NE or {}

-- 1. 初期化ログ (INFO)
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "Load:START", "INFO")
end

-- --------------------------------------------------------------------------
-- Dr.Hiro 導線: 離脱リマインド（最大5回）→ 鍵なしなら起床リマインド
-- Dr.Hiro 遺体座標に合わせた基点（NE_StartScene HIRO_X/Y と同期）
-- --------------------------------------------------------------------------
local HIRO_REMINDER_X, HIRO_REMINDER_Y = 15641, 3909
local REMINDER_DIST_SQ = 100

local hiroReminderTick = 0

--- B17 鍵を所持しているか（リマインド停止の共通判定）
---@param player IsoPlayer
local function NE_PlayerHasB17AccessKey(player)
    local inv = player and player:getInventory()
    return inv ~= nil and inv:containsTypeRecurse("NOX_EVO_B42.B17_AccessKey") == true
end

---@param player IsoPlayer
local function NE_SilenceHiroRemindersIfHasKey(player, modData)
    if NE_PlayerHasB17AccessKey(player) then
        modData.NE_HiroRemindersSilenced = true
        return true
    end
    return modData.NE_HiroRemindersSilenced == true
end

--- 離脱リマインド5回後も鍵がない場合、起床のたびに追奏（EveryOneMinute から起床遷移時に呼ぶ）
---@param player IsoPlayer
local function onPlayerWakeHiroReminder(player)
    if not player or player:isDead() then return end
    local modData = player:getModData()
    if NE_SilenceHiroRemindersIfHasKey(player, modData) then
        return
    end
    local count = modData.NE_HiroReminderCount or 0
    if count < 5 then
        return
    end
    player:Say(getText("UI_NE_Card_Reminder_Wake"))
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_SCENE", "Reminder", "Wake|count=" .. tostring(count), "DEBUG")
    end
end

local function checkHiroReminder()
    hiroReminderTick = hiroReminderTick + 1
    if hiroReminderTick % 60 ~= 0 then
        return
    end

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local modData = player:getModData()
            if NE_SilenceHiroRemindersIfHasKey(player, modData) then
                -- 鍵入手済み or 永久停止
            else
                local count = modData.NE_HiroReminderCount or 0
                if count < 5 then
                    local dx = player:getX() - HIRO_REMINDER_X
                    local dy = player:getY() - HIRO_REMINDER_Y
                    local distSq = (dx * dx) + (dy * dy)
                    if distSq >= REMINDER_DIST_SQ then
                        player:Say(getText("UI_NE_Card_Reminder_Dist"))
                        modData.NE_HiroReminderCount = count + 1
                        if Z_TRACER and Z_TRACER.EmitTrace then
                            Z_TRACER.EmitTrace("NE_SCENE", "Reminder",
                                "Dist|count=" .. tostring(modData.NE_HiroReminderCount), "INFO")
                        end
                    end
                end
            end
        end
    end
end

--- 定期的な生存判定（1分ごと）
local function OnEveryOneMinute()
    -- HEARTBEAT ログ (DEBUGレベル: 毎分のイベント発火を確認)
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_HEARTBEAT", "PlayerManager", "EveryOneMinute", "DEBUG")
    end

    -- 稼働している全プレイヤー（画面分割含む）に対してループ
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local modData = player:getModData()

            local isAsleep = player:isAsleep()
            local wasAsleep = modData.NE_WasAsleep or false
            if not isAsleep and wasAsleep then
                onPlayerWakeHiroReminder(player)
            end
            modData.NE_WasAsleep = isAsleep

            local x = player:getX()
            local y = player:getY()

            -- 前回の計算地点からの距離を確認 (10タイルの閾値)
            local lastX = modData.NE_LastUpdateX or -9999
            local lastY = modData.NE_LastUpdateY or -9999
            local dx = x - lastX
            local dy = y - lastY
            local distSq = (dx * dx) + (dy * dy)

            -- 日付が変わったかどうかもチェック
            local currentDay = NE.GetCurrentDay and NE.GetCurrentDay() or -1
            local lastDay = modData.NE_LastUpdateDay or -1

            -- 10タイル以上の移動があったか、または日付が変わった場合のみ再計算する
            local forceRecalc = (distSq >= 100) or (currentDay ~= lastDay)

            if forceRecalc then
                modData.NE_LastUpdateX = x
                modData.NE_LastUpdateY = y
                modData.NE_LastUpdateDay = currentDay
            end

            -- 変異度更新処理の実行 (ガード節とエラーログ)
            if NE.UpdateMutation then
                NE.UpdateMutation(player, forceRecalc)
            else
                if Z_TRACER and Z_TRACER.EmitTrace then
                    Z_TRACER.EmitTrace("NE_ERROR", "PlayerManager", "UpdateMutation:MISSING", "ERROR")
                end
            end
        end
    end
end

-- イベント登録
Events.EveryOneMinute.Add(OnEveryOneMinute)

-- 2. 完了ログ (INFO)
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "Load:DONE", "INFO")
end

Events.OnTick.Add(checkHiroReminder)
