print(">>> [NE] PLAYER MANAGER IS ALIVE")
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
-- 変異度: OnGameStart のみでシード（OnCreatePlayer はバニラ側リスクのため使わない）
-- --------------------------------------------------------------------------
---@param player IsoPlayer|nil
---@param sourceTag string
local function NE_EnsureMutationLevelImmediate(player, sourceTag)
    if not player or player:isDead() then
        return
    end
    local md = player:getModData()
    if not md then
        return
    end
    if md.NE_MutationLevel == nil then
        md.NE_MutationLevel = 20.0
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace(
                "NE_MUTATION",
                "Bootstrap",
                "Fired|context=" .. tostring(sourceTag) .. "|level=20.0",
                "INFO"
            )
        end
    end
end

local function NE_OnGameStartMutationSeed()
    for i = 0, getNumActivePlayers() - 1 do
        NE_EnsureMutationLevelImmediate(getSpecificPlayer(i), "OnGameStart")
    end
end

Events.OnGameStart.Add(NE_OnGameStartMutationSeed)

-- --------------------------------------------------------------------------
-- Dr.Hiro 導線: 離脱リマインド（最大5回）→ 鍵なしなら起床リマインド
-- Dr.Hiro 遺体座標に合わせた基点（NE_StartScene HIRO_X/Y と同期）
-- --------------------------------------------------------------------------
local HIRO_REMINDER_X, HIRO_REMINDER_Y = 15642, 3909
local REMINDER_DIST_SQ = 100

local hiroReminderTick = 0

--- マスターキー + クエスト報告書の両方を所持しているか（リマインド永久停止の判定）
---@param player IsoPlayer
local function NE_PlayerHasB17RequiredItems(player)
    local inv = player and player:getInventory()
    if not inv then
        return false
    end
    return inv:containsTypeRecurse("NOX_EVO_B42.NE_AccessKey") == true
        and inv:containsTypeRecurse("NOX_EVO_B42.NE_QuestReport") == true
end

---@param player IsoPlayer
local function NE_SilenceHiroRemindersIfHasKey(player, modData)
    if modData.NE_HiroRemindersSilenced == true then
        return true
    end
    if NE_PlayerHasB17RequiredItems(player) then
        modData.NE_HiroRemindersSilenced = true
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Reminder:Silenced|KeyFound", "INFO")
        end
        return true
    end
    return false
end

--- 離脱リマインド5回後も導線アイテム未達の場合、起床のたびに追奏（isAsleep 遷移で検知）
---@param player IsoPlayer
local function onPlayerWakeHiroReminder(player)
    if not player or player:isDead() then return end
    local modData = player:getModData()
    if not modData then return end
    if modData.NE_HiroRemindersSilenced == true then
        return
    end
    if NE_SilenceHiroRemindersIfHasKey(player, modData) then
        return
    end
    local count = modData.NE_HiroReminderCount or 0
    if count < 5 then
        return
    end
    player:Say(getText("UI_NE_Card_Reminder_Wake"))
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Reminder:Wake", "DEBUG")
    end
end

local function checkHiroReminder()
    local tickPulse = (hiroReminderTick % 60 == 0)

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local modData = player:getModData()
            local isCurrentlyAsleep = player:isAsleep()

            -- 起床検知 (Events.OnPlayerWake の代替)
            if modData.NE_WasAsleep == true and not isCurrentlyAsleep then
                if Z_TRACER and Z_TRACER.EmitTrace then
                    Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Reminder:Wake:Detected", "INFO")
                end
                onPlayerWakeHiroReminder(player)
            end
            modData.NE_WasAsleep = isCurrentlyAsleep

            if tickPulse then
                if NE_SilenceHiroRemindersIfHasKey(player, modData) then
                    -- 鍵+報告書入手済み or 永久停止
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
                                Z_TRACER.EmitTrace("NE_SCENE", "DrHiro",
                                    "Reminder:Dist|count=" .. tostring(modData.NE_HiroReminderCount), "INFO")
                            end
                        end
                    end

                    -- 導線アイテム欠落時のセーフティリスポーン（Hiro 基点半径 20 タイル・固定座標ドロップ・重複防止）
                    local dxHiro = player:getX() - HIRO_REMINDER_X
                    local dyHiro = player:getY() - HIRO_REMINDER_Y
                    local hasItems = NE_PlayerHasB17RequiredItems(player)
                    if (dxHiro * dxHiro + dyHiro * dyHiro) < 400.0 and not hasItems then
                        local cell = getCell()
                        local targetSq = cell and cell:getGridSquare(15642, 3910, 0)
                        if targetSq and modData.NE_HiroItemSafetyRespawned ~= true then
                            targetSq:AddWorldInventoryItem("NOX_EVO_B42.NE_AccessKey", 0.5, 0.5, 0)
                            targetSq:AddWorldInventoryItem("NOX_EVO_B42.NE_QuestReport", 0.6, 0.4, 0)
                            modData.NE_HiroItemSafetyRespawned = true
                        end
                    end
                end
            end
        end
    end
    hiroReminderTick = hiroReminderTick + 1
end

--- HUD / 台詞共通: Clean(0–24) / Unstable / Danger / Critical / EVOLVED(100)
---@param mutation number
---@return string
function NE.GetMutationSpeechTier(mutation)
    if mutation >= 100 then
        return "EVOLVED"
    end
    if mutation >= 75 then
        return "Critical"
    end
    if mutation >= 50 then
        return "Danger"
    end
    if mutation >= 25 then
        return "Unstable"
    end
    return "Clean"
end

--- 変異度段階のランダム台詞（キー: UI_NE_Speech_Mutation_{Clean|Unstable|Danger|Critical|EVOLVED}_1..10）
---@param subType string
---@return string
function NE.GetRandomMutationSpeech(subType)
    local index = ZombRand(10) + 1
    local key = "UI_NE_Speech_Mutation_" .. subType .. "_" .. tostring(index)
    return getText(key)
end

--- 境界演出用の痛み系 SFX（プレイヤー性別に合わせる）
---@param player IsoPlayer|IsoGameCharacter|nil
---@return string
function NE.GetGenderedPainSoundName(player)
    if player and player.isFemale and player:isFemale() then
        return "FemalePain"
    end
    return "MalePain"
end

--- 変異度: 台詞（境界＋頻度・クールダウン）と肉体症状（仕様 4.2: 25%〜 Unstable から段階的）
---@param player IsoPlayer
---@param modData table
function NE.ApplySymptoms(player, modData)
    if not player or player:isDead() then
        return
    end
    if NE.Switches and NE.Switches.EnableMutation == false then
        return
    end
    if not modData then
        return
    end

    local gt0 = getGameTime()
    local worldMin = (gt0 and gt0.getWorldAgeHours and (gt0:getWorldAgeHours() * 60)) or 0
    if modData.NE_LastSymptomTick == worldMin then
        return
    end
    modData.NE_LastSymptomTick = worldMin

    local noxVars = SandboxVars and (SandboxVars.NOX_EVO_B42 or SandboxVars.NOX_EVOLVED or SandboxVars.NOX_EVO)
    local instinctOn = (not noxVars) or (noxVars.InstinctVoice ~= false)

    local mutation = modData.NE_MutationLevel or 0
    local prev = modData.NE_SymptomPrevMutationLevel
    if prev == nil then
        prev = mutation
    end

    local sq = player.getCurrentSquare and player:getCurrentSquare() or nil
    local bd = player.getBodyDamage and player:getBodyDamage() or nil

    local function playSymptomSound(soundName)
        local em = player.getEmitter and player:getEmitter() or nil
        if em and type(em["playSound"]) == "function" then
            em:playSound(soundName)
        elseif type(player["playSound"]) == "function" then
            player:playSound(soundName)
        end
    end

    local function crossedUp(threshold)
        return prev < threshold and mutation >= threshold
    end

    local function enteredClean()
        return prev >= 25 and mutation < 25
    end

    local boundaryFired = false
    if instinctOn then
        if enteredClean() then
            player:Say(NE.GetRandomMutationSpeech("Clean"))
            playSymptomSound(NE.GetGenderedPainSoundName(player))
            boundaryFired = true
        elseif crossedUp(25) then
            player:Say(NE.GetRandomMutationSpeech("Unstable"))
            playSymptomSound(NE.GetGenderedPainSoundName(player))
            boundaryFired = true
        elseif crossedUp(50) then
            player:Say(NE.GetRandomMutationSpeech("Danger"))
            playSymptomSound("Vomit")
            boundaryFired = true
        elseif crossedUp(75) then
            player:Say(NE.GetRandomMutationSpeech("Critical"))
            playSymptomSound(NE.GetGenderedPainSoundName(player))
            boundaryFired = true
        elseif crossedUp(100) then
            player:Say(NE.GetRandomMutationSpeech("EVOLVED"))
            playSymptomSound(NE.GetGenderedPainSoundName(player))
            boundaryFired = true
        end

        -- 境界越え後は即座に周期用クールダウンを設け、二重発言を抑える
        if boundaryFired then
            modData.NE_MutationSpeechCooldownUntil = worldMin
                + math.max(2, 9 - math.floor(mutation / 14))
        end

        -- 変異度に応じた頻度（高いほど試行率↑・成功後クールダウン↓）
        local untilT = modData.NE_MutationSpeechCooldownUntil or 0
        if worldMin >= untilT then
            local rollChance = math.min(50, 4 + math.floor(mutation * 0.44))
            if ZombRand(100) < rollChance then
                player:Say(NE.GetRandomMutationSpeech(NE.GetMutationSpeechTier(mutation)))
                modData.NE_MutationSpeechCooldownUntil = worldMin
                    + math.max(2.0, 11.0 - (mutation / 9.0))
            else
                modData.NE_MutationSpeechCooldownUntil = worldMin + 1.0
            end
        end
    end

    modData.NE_SymptomPrevMutationLevel = mutation

    local stats = player.getStats and player:getStats() or nil

    local function tryAddMutationWorldSound(radius)
        local wsm = getWorldSoundManager and getWorldSoundManager() or nil
        if not wsm or not sq then
            return
        end
        local x = player:getX()
        local y = player:getY()
        local z = player:getZ()
        local vol = 50
        if wsm and type(wsm.AddSound) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                wsm:AddSound(player, x, y, z, radius, vol)
            end)
        elseif wsm and type(wsm.addSound) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                wsm:addSound(player, x, y, z, radius, vol)
            end)
        end
    end

    -- Unstable 25–49%: 軽いパニック・めまい（仕様 4.2 / HP 減少なし）
    if mutation >= 25 and mutation < 50 then
        if stats and type(stats["setPanic"]) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                stats:setPanic(0.42)
            end)
        end
        if stats and type(stats["setDrunkenness"]) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                stats:setDrunkenness(0.32)
            end)
        end
    end

    -- Danger 50%〜: 変異性の咳・パニック・吐血・HP 減少（毎10分表記を 1分 tick で /10）
    if mutation >= 50 then
        if stats and type(stats["setPanic"]) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                stats:setPanic(1.0)
            end)
        end

        local coughChance = math.min(92, 18 + math.floor((mutation - 50) * 1.15))
        if ZombRand(100) < coughChance then
            local coughSnd = (player.isFemale and player:isFemale()) and "FemaleCough" or "MaleCough"
            playSymptomSound(coughSnd)
            local rad = math.min(30, 8 + math.floor((mutation - 50) * 0.44))
            tryAddMutationWorldSound(rad)
            local bloodChance = math.min(88, 22 + math.floor((mutation - 50) * 0.7))
            if ZombRand(100) < bloodChance and sq and type(sq.splatBlood) == "function" then
                local intensity = mutation >= 100 and 9 or (mutation >= 75 and 7 or 5)
                sq:splatBlood(intensity, intensity)
                if mutation >= 75 then
                    sq:splatBlood(math.max(3, intensity - 2), math.max(3, intensity - 2))
                end
                if mutation >= 100 then
                    sq:splatBlood(6, 6)
                end
            end
        end

        -- Critical 75%〜: 発熱系（FoodSickness で近似）
        if mutation >= 75 and stats and type(stats["setFoodSicknessLevel"]) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                stats:setFoodSicknessLevel(0.14)
            end)
        end

        local hpLoss = 0.0
        if mutation >= 100 then
            hpLoss = 2.0
        elseif mutation >= 75 then
            hpLoss = 1.0
        else
            hpLoss = 0.2
        end

        if hpLoss > 0 and bd and type(bd["getHealth"]) == "function" and type(bd["setHealth"]) == "function" then
            local cur = bd:getHealth()
            if cur ~= nil then
                pcall(function()
                    ---@diagnostic disable-next-line: undefined-field
                    bd:setHealth(cur - hpLoss)
                end)
            end
        end
    end

    -- 100% EVOLVED: 跛行・移動 50%（仕様 4.2 / スプリント禁止は OnPlayerUpdate で補強）
    if mutation >= 100 then
        if type(player.setMoveSpeed) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                player:setMoveSpeed(0.5)
            end)
        end
        modData.NE_MutationSpeedDebuffOn = true
        modData.NE_MutationLimpApplied = true
    else
        if modData.NE_MutationSpeedDebuffOn then
            if type(player.setMoveSpeed) == "function" then
                pcall(function()
                    ---@diagnostic disable-next-line: undefined-field
                    player:setMoveSpeed(1.0)
                end)
            end
            modData.NE_MutationSpeedDebuffOn = nil
        end
        if modData.NE_MutationLimpApplied then
            pcall(function()
                if type(player.setLimped) == "function" then
                    ---@diagnostic disable-next-line: undefined-field
                    player:setLimped(false)
                elseif type(player.setLimping) == "function" then
                    ---@diagnostic disable-next-line: undefined-field
                    player:setLimping(false)
                end
            end)
            modData.NE_MutationLimpApplied = nil
        end
        if modData.NE_MutationEvolvedIgnoreRun and type(player.setIgnoreRun) == "function" then
            pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                player:setIgnoreRun(false)
            end)
            modData.NE_MutationEvolvedIgnoreRun = nil
        end
    end
end

--- EVOLVED(100%) が誰もいなければ OnPlayerUpdate から外し、負荷を抑える
local NE_EvolvedMovementLockSubscribed = false

function NE.SyncEvolvedMovementLockGlobally()
    local need = false
    if not (NE.Switches and NE.Switches.EnableMutation == false) then
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p and not p:isDead() then
                local md = p:getModData()
                if md and (md.NE_MutationLevel or 0) >= 100 then
                    need = true
                    break
                end
            end
        end
    end
    if need and not NE_EvolvedMovementLockSubscribed then
        Events.OnPlayerUpdate.Add(NE_MutationEvolvedMovementLock)
        NE_EvolvedMovementLockSubscribed = true
    elseif not need and NE_EvolvedMovementLockSubscribed then
        Events.OnPlayerUpdate.Remove(NE_MutationEvolvedMovementLock)
        NE_EvolvedMovementLockSubscribed = false
    end
end

--- 100% 時: スプリント抑止・跛行の維持（毎分だけでは入力で上書きされるため）
---@param player IsoPlayer|nil
local function NE_MutationEvolvedMovementLock(player)
    if not player or player:isDead() then
        return
    end
    if NE.Switches and NE.Switches.EnableMutation == false then
        return
    end
    local md = player:getModData()
    if not md then
        return
    end
    if (md.NE_MutationLevel or 0) < 100 then
        return
    end
    if type(player.setSprinting) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setSprinting(false)
        end)
    end
    if type(player.setRunning) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setRunning(false)
        end)
    end
    if type(player.setIgnoreRun) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setIgnoreRun(true)
        end)
        md.NE_MutationEvolvedIgnoreRun = true
    end
    if type(player.setLimped) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setLimped(true)
        end)
    elseif type(player.setLimping) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setLimping(true)
        end)
    end
end

--- 定期的な生存判定（1分ごと）
local function OnEveryOneMinute()
    -- [NUCLEAR CLEANUP] 入力ブロック・ポーズ表示の保険解除（一時）
    pcall(function()
        local core = getCore()
        if core and type(core.setBlockAllInput) == "function" then
            core:setBlockAllInput(false)
        end
    end)
    pcall(function()
        if UIManager and type(UIManager.setShowPausedMessage) == "function" then
            UIManager.setShowPausedMessage(false)
        end
    end)

    -- HEARTBEAT ログ (DEBUGレベル: 必要に応じてコメントアウトを解除)
    -- if Z_TRACER and Z_TRACER.EmitTrace then
    --     Z_TRACER.EmitTrace("NE_HEARTBEAT", "PlayerManager", "EveryOneMinute", "DEBUG")
    -- end

    -- 稼働している全プレイヤー（画面分割含む）に対してループ
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local modData = player:getModData()

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
            if NE.ApplySymptoms then
                NE.ApplySymptoms(player, modData)
            end
        end
    end
    NE.SyncEvolvedMovementLockGlobally()
end

-- イベント登録
Events.EveryOneMinute.Add(OnEveryOneMinute)

Events.OnGameStart.Add(function()
    NE.SyncEvolvedMovementLockGlobally()
end)

-- 2. 完了ログ (INFO)
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "Load:DONE", "INFO")
end

Events.OnTick.Add(checkHiroReminder)
