print(">>> [NE] PLAYER MANAGER IS ALIVE")
-- NE_PlayerManager.lua: Syntax OK check (remove after verify)
-- --------------------------------------------------------------------------
-- Path: media/lua/client/NE_PlayerManager.lua
-- Role: プレイヤー単位の生存ロジックの管理 (クライアント側)
-- --------------------------------------------------------------------------

NE = NE or {}
--- HUD / 健康パネル / 台詞の EVOLVED 境界（%）。単一の参照元（NE_PlayerManager が既定を設定）。
if type(NE.MUTATION_EVOLVED_THRESHOLD) ~= "number" then
    NE.MUTATION_EVOLVED_THRESHOLD = 99.5
end
local NE_MUTATION_EVOLVED_THRESHOLD = NE.MUTATION_EVOLVED_THRESHOLD

--- B42: IsoPlayer 基準移動速度（setMoveSpeed 用）
local NE_MOVE_SPEED_BASE = 0.06

--- 移動倍率: 75% 未満 1.0。75–100% 線形（0.06*0.75=0.045 → 0.06*0.5=0.030）。t=(mutation_0_1-0.75)/0.25、m=1-(0.25+t*0.25)
---@param mutationPct number
---@return number
local function NE_ComputeMutationSpeedMultiplier(mutationPct)
    local m = tonumber(mutationPct) or 0
    if m < 75 then
        return 1.0
    end
    local mutation_0_1 = math.min(1.0, math.max(0, m / 100))
    local t = (mutation_0_1 - 0.75) / 0.25
    return 1.0 - (0.25 + t * 0.25)
end

--- B42: getSpecificPlayer / ティック間で非 IsoPlayer が混ざるため、メソッド触り前に必須
---@param player any
---@return boolean
local function NE_IsValidPlayer(player)
    if not player then
        return false
    end
    if type(player) ~= "userdata" then
        return false
    end
    if type(instanceof) ~= "function" then
        return false
    end
    return instanceof(player, "IsoPlayer") == true
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param allowRun boolean
---@param allowSprint boolean
local function NE_ApplyRunSprintAuthority(player, allowRun, allowSprint)
    if not NE_IsValidPlayer(player) then
        return
    end
    if type(player.setAllowRun) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setAllowRun(allowRun)
        end)
    end
    if type(player.setAllowSprint) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setAllowSprint(allowSprint)
        end)
    end
end

--- 速度権威: WalkSpeed / MoveDelta（文字列）+ setMoveSpeed + setMoveDelta + setSpeedMod + setAnimationSpeedModifier（あれば）+ Torso 感染 + stats:set(PAIN)。OnTick と OnPlayerUpdate の両方から呼ばれうる
---@param player IsoPlayer|IsoGameCharacter|nil
---@param mutationPct number 変異度 0–100
local function NE_ApplyMutationSpeedAuthority(player, mutationPct)
    if not NE_IsValidPlayer(player) then
        return
    end

    local mut = tonumber(mutationPct) or 0
    local m = NE_ComputeMutationSpeedMultiplier(mut)

    if type(player.setVariable) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setVariable("WalkSpeed", tostring(0.06 * m))
        end)
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setVariable("MoveDelta", tostring(m))
        end)
    end
    if type(player.setMoveSpeed) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setMoveSpeed(NE_MOVE_SPEED_BASE * m)
        end)
    end
    if type(player.setMoveDelta) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setMoveDelta(m)
        end)
    end
    if type(player.setAnimationSpeedModifier) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setAnimationSpeedModifier(m)
        end)
    end
    if type(player.setSpeedMod) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            player:setSpeedMod(m)
        end)
    end

    local bd = nil
    if type(player.getBodyDamage) == "function" then
        local okBd, v = pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            return player:getBodyDamage()
        end)
        if okBd then
            bd = v
        end
    end
    if bd then
        local BPT = rawget(_G, "BodyPartType")
        if BPT and BPT.Torso_Upper and type(bd.getBodyPart) == "function" then
            local part = nil
            local okP, p = pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                return bd:getBodyPart(BPT.Torso_Upper)
            end)
            if okP then
                part = p
            end
            if part then
                pcall(function()
                    ---@diagnostic disable-next-line: undefined-field
                    part:setInfectedWound(mut >= 25)
                    ---@diagnostic disable-next-line: undefined-field
                    part:setWoundInfectionLevel(mut)
                end)
            end
        end
    end

    local stats = nil
    if type(player.getStats) == "function" then
        local okSt, s = pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            return player:getStats()
        end)
        if okSt then
            stats = s
        end
    end
    local CS = rawget(_G, "CharacterStat")
    if stats and CS and CS.PAIN and type(stats.set) == "function" then
        local t = (mut - 75) / 25
        local painValue = math.max(0, math.min(100, t * 100))
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            stats:set(CS.PAIN, painValue)
        end)
    end
end

---@param stats userdata|nil
---@param statEnum any
---@param value number
---@return boolean
local function NE_TryStatsSet(stats, statEnum, value)
    if not stats or statEnum == nil or type(stats.set) ~= "function" then
        return false
    end
    local ok = pcall(function()
        ---@diagnostic disable-next-line: undefined-field
        stats:set(statEnum, value)
    end)
    return ok
end

---@param stats userdata|nil
---@param statEnum any
---@return number|nil
local function NE_TryStatsGet(stats, statEnum)
    if not stats or statEnum == nil or type(stats.get) ~= "function" then
        return nil
    end
    local ok, v = pcall(function()
        ---@diagnostic disable-next-line: undefined-field
        return stats:get(statEnum)
    end)
    if ok then
        return v
    end
    return nil
end

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
    if not NE_IsValidPlayer(player) or player:isDead() then
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
    if not NE_IsValidPlayer(player) then
        return false
    end
    local inv = player:getInventory()
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
    if not NE_IsValidPlayer(player) or player:isDead() then
        return
    end
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
        if NE_IsValidPlayer(player) and not player:isDead() then
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

--- HUD / 台詞共通: Clean(0–24) / Unstable / Danger / Critical / EVOLVED(99.5+)
---@param mutation number
---@return string
function NE.GetMutationSpeechTier(mutation)
    if mutation >= NE_MUTATION_EVOLVED_THRESHOLD then
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

--- 痛み系 SFX 名（B42: モジュール完全修飾）。境界越えでは未使用（隠密仕様）。
---@param player IsoPlayer|IsoGameCharacter|nil
---@return string
function NE.GetGenderedPainSoundName(player)
    if player and player.isFemale and player:isFemale() then
        return "Base.FemalePain"
    end
    return "Base.MalePain"
end

--- 変異度（%）→ GetMutationSpeechTier と同じ Clean〜EVOLVED の UI_NE_Status_* 表記（健康パネル・NE_ViralStressHUD チップと同一文字列）
---@param mutationPct number
---@return string
function NE.GetMutationSeverityText(mutationPct)
    local mut = tonumber(mutationPct) or 0
    local tier = NE.GetMutationSpeechTier(mut)
    return getText("UI_NE_Status_" .. tier)
end

--- 変異度: 台詞（境界＋頻度・クールダウン）と肉体症状（仕様 4.2: 25%〜 Unstable から段階的）
---@param player IsoPlayer
---@param modData table
function NE.ApplySymptoms(player, modData)
    if not NE_IsValidPlayer(player) or player:isDead() then
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
            boundaryFired = true
        elseif crossedUp(25) then
            player:Say(NE.GetRandomMutationSpeech("Unstable"))
            boundaryFired = true
        elseif crossedUp(50) then
            player:Say(NE.GetRandomMutationSpeech("Danger"))
            boundaryFired = true
        elseif crossedUp(75) then
            player:Say(NE.GetRandomMutationSpeech("Critical"))
            boundaryFired = true
        elseif crossedUp(NE_MUTATION_EVOLVED_THRESHOLD) then
            player:Say(NE.GetRandomMutationSpeech("EVOLVED"))
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
    --- Z_TRACER 用: 本 tick で意図した CharacterStat set 値（下の set と式を同期すること）
    local neTracePanic, neTraceDizzy = 0, 0
    local neTraceFood = (mutation >= 75) and 40 or 0
    local neTraceHpLoss = 0.0
    local CS = rawget(_G, "CharacterStat")
    -- Panic / INTOXICATION: 0–25→0–15、25–50→15–30、50–100→30–100（ノード間線形）
    local moodVal = 0
    if mutation <= 0 then
        moodVal = 0
    elseif mutation < 25 then
        moodVal = mutation * (15 / 25)
    elseif mutation < 50 then
        moodVal = 15 + (mutation - 25) * (15 / 25)
    else
        local m = math.min(100, mutation)
        moodVal = 30 + (m - 50) * (70 / 50)
        moodVal = math.min(100, moodVal)
    end
    neTracePanic = moodVal
    neTraceDizzy = moodVal

    local function tryAddMutationWorldSound(radius)
        local wsm = getWorldSoundManager and getWorldSoundManager() or nil
        if not wsm or not sq then
            return
        end
        local x = player:getX()
        local y = player:getY()
        local z = player:getZ()
        local vol = 70
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

    -- ムードル B42: stats:set(CharacterStat.*, 0–100)。INTOXICATION = めまい代用。FOOD_SICKNESS は 75% 以上で 40（レベル2相当）
    if stats and CS and CS.PANIC and CS.INTOXICATION and CS.FOOD_SICKNESS then
        NE_TryStatsSet(stats, CS.PANIC, neTracePanic)
        NE_TryStatsSet(stats, CS.INTOXICATION, neTraceDizzy)
        NE_TryStatsSet(stats, CS.FOOD_SICKNESS, neTraceFood)
    end

    -- Danger 50%〜: 変異性の咳・吐血・HP 減少（パニック等は上記で累積適用）
    if mutation >= 50 then
        local wm = tonumber(worldMin) or 0
        local lc = tonumber(modData.NE_LastCoughTime)
        local coughCooldownOk = (lc == nil) or (wm - lc >= 5)

        local coughChance = math.min(92, 18 + math.floor((mutation - 50) * 1.15))
        if coughCooldownOk and ZombRand(100) < coughChance then
            player:Say(getText("UI_NE_Symptom_Cough"))
            local coughSnd = (player.isFemale and player:isFemale()) and "Base.FemaleCough" or "Base.MaleCough"
            if type(player.playSound) == "function" then
                player:playSound(coughSnd)
            end
            local rad = math.min(30, 8 + math.floor((mutation - 50) * 0.44))
            tryAddMutationWorldSound(rad)
            modData.NE_LastCoughTime = worldMin
            local bloodChance = math.min(88, 22 + math.floor((mutation - 50) * 0.7))
            if ZombRand(100) < bloodChance and sq and type(sq.splatBlood) == "function" then
                local intensity = mutation >= NE_MUTATION_EVOLVED_THRESHOLD and 9 or (mutation >= 75 and 7 or 5)
                sq:splatBlood(intensity, intensity)
                if mutation >= 75 then
                    sq:splatBlood(math.max(3, intensity - 2), math.max(3, intensity - 2))
                end
                if mutation >= NE_MUTATION_EVOLVED_THRESHOLD then
                    sq:splatBlood(6, 6)
                end
            end
        end

        local hpLoss = 0.0
        if mutation >= 100 then
            hpLoss = 2.0
        elseif mutation >= 75 then
            hpLoss = 1.0
        else
            hpLoss = 0.2
        end
        neTraceHpLoss = hpLoss

        if hpLoss > 0 and bd then
            local BPT = rawget(_G, "BodyPartType")
            if BPT and BPT.Torso_Upper and type(bd.getBodyPart) == "function" then
                local part = bd:getBodyPart(BPT.Torso_Upper)
                if part and type(part.AddDamage) == "function" then
                    pcall(function()
                        ---@diagnostic disable-next-line: undefined-field
                        part:AddDamage(hpLoss)
                    end)
                end
            end
        end
    end

    -- 移動: OnTick（NE_MutationEvolvedMovementLock）で変数+速度+SpeedMod+PAIN（NE_ApplyMutationSpeedAuthority）

    if Z_TRACER and Z_TRACER.EmitTrace then
        local rgPanic, rgDizzy, rgFood = nil, nil, nil
        if stats and CS and CS.PANIC and CS.INTOXICATION and CS.FOOD_SICKNESS then
            rgPanic = NE_TryStatsGet(stats, CS.PANIC)
            rgDizzy = NE_TryStatsGet(stats, CS.INTOXICATION)
            rgFood = NE_TryStatsGet(stats, CS.FOOD_SICKNESS)
        end
        local rgMoveDelta = "nil"
        if type(player.getMoveDelta) == "function" then
            local okMd, vMd = pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                return player:getMoveDelta()
            end)
            if okMd and vMd ~= nil then
                local nMd = tonumber(vMd)
                if nMd then
                    rgMoveDelta = string.format("%.3f", nMd)
                end
            end
        end
        Z_TRACER.EmitTrace(
            "NE_SYMPTOMS",
            "ApplySymptoms",
            string.format(
                "mutation=%.2f|setPanic=%.2f|setIntox=%.2f|setFood=%d|hpLoss=%.2f|getPanic=%s|getIntox=%s|getFood=%s|getMoveDelta=%s|worldMin=%.1f|moveAuthority=OnTick:var+speed+delta+speedMod+PAIN|healthInf=OnTick:setInfectedWound+setWoundInfectionLevel|limp=off",
                mutation,
                neTracePanic,
                neTraceDizzy,
                neTraceFood,
                neTraceHpLoss,
                rgPanic ~= nil and string.format("%.2f", tonumber(rgPanic) or 0) or "nil",
                rgDizzy ~= nil and string.format("%.2f", tonumber(rgDizzy) or 0) or "nil",
                rgFood ~= nil and string.format("%.2f", tonumber(rgFood) or 0) or "nil",
                rgMoveDelta,
                worldMin
            ),
            "DEBUG"
        )
    end

    -- コンティニュー直後など: 次の EveryOneMinute 周回を待たず OnTick 購読を同期（NE_MutationEvolvedMovementLock）
    pcall(function()
        NE.SyncEvolvedMovementLockGlobally()
    end)
end

--- 毎ティック: NE_ApplyMutationSpeedAuthority（速度+PAIN）+ setAllowRun / setAllowSprint（99.5%+ で走行・スプリント禁止）
local function NE_MutationEvolvedMovementLock()
    if NE.Switches and NE.Switches.EnableMutation == false then
        return
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if NE_IsValidPlayer(player) and not player:isDead() then
            local md = player:getModData()
            local mut = (md and tonumber(md.NE_MutationLevel)) or 0
            NE_ApplyMutationSpeedAuthority(player, mut)

            if not md or mut < 75 then
                NE_ApplyRunSprintAuthority(player, true, true)
                if md then
                    md.NE_MutationEvolvedIgnoreRun = nil
                end
            elseif mut < NE_MUTATION_EVOLVED_THRESHOLD then
                NE_ApplyRunSprintAuthority(player, true, true)
                md.NE_MutationEvolvedIgnoreRun = nil
            else
                NE_ApplyRunSprintAuthority(player, false, false)
                md.NE_MutationEvolvedIgnoreRun = true
            end
        end
    end
end

--- 変異度 25% 未満が全員なら OnTick から外し、Torso 感染表示・速度権威の毎ティック更新を停止（75%+ 走破禁止は NE_MutationEvolvedMovementLock 内）
local NE_EvolvedMovementLockSubscribed = false

function NE.SyncEvolvedMovementLockGlobally()
    local need = false
    if not (NE.Switches and NE.Switches.EnableMutation == false) then
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if NE_IsValidPlayer(p) and not p:isDead() then
                local md = p:getModData()
                if md and (tonumber(md.NE_MutationLevel) or 0) >= 25 then
                    need = true
                    break
                end
            end
        end
    end
    if need and not NE_EvolvedMovementLockSubscribed then
        Events.OnTick.Add(NE_MutationEvolvedMovementLock)
        NE_EvolvedMovementLockSubscribed = true
    elseif not need and NE_EvolvedMovementLockSubscribed then
        for j = 0, getNumActivePlayers() - 1 do
            local p2 = getSpecificPlayer(j)
            if NE_IsValidPlayer(p2) and not p2:isDead() then
                local md2 = p2:getModData()
                local mut2 = (md2 and tonumber(md2.NE_MutationLevel)) or 0
                NE_ApplyMutationSpeedAuthority(p2, mut2)
                NE_ApplyRunSprintAuthority(p2, true, true)
                if md2 then
                    md2.NE_MutationEvolvedIgnoreRun = nil
                end
            end
        end
        Events.OnTick.Remove(NE_MutationEvolvedMovementLock)
        NE_EvolvedMovementLockSubscribed = false
    end
end

--- OnPlayerUpdate: エンジン直後に速度系のみ即再適用（OnTick と二重。装備・素足の上書き対策）
local NE_MutationSpeedOnPlayerUpdateHooked = false

local function NE_MutationSpeedAuthorityOnPlayerUpdate(player)
    if NE.Switches and NE.Switches.EnableMutation == false then
        return
    end
    if not NE_IsValidPlayer(player) or player:isDead() then
        return
    end
    local md = nil
    if type(player.getModData) == "function" then
        local ok, v = pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            return player:getModData()
        end)
        if ok then
            md = v
        end
    end
    local mut = (md and tonumber(md.NE_MutationLevel)) or 0
    if mut < 25 then
        return
    end
    NE_ApplyMutationSpeedAuthority(player, mut)
end

local function NE_RegisterMutationSpeedOnPlayerUpdateOnce()
    if NE_MutationSpeedOnPlayerUpdateHooked then
        return
    end
    if Events and type(Events.OnPlayerUpdate) == "table" and type(Events.OnPlayerUpdate.Add) == "function" then
        Events.OnPlayerUpdate.Add(NE_MutationSpeedAuthorityOnPlayerUpdate)
        NE_MutationSpeedOnPlayerUpdateHooked = true
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "OnPlayerUpdate:SpeedAuthority:ADDED", "INFO")
        end
    end
end

NE_RegisterMutationSpeedOnPlayerUpdateOnce()

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
        if NE_IsValidPlayer(player) and not player:isDead() then
            local modData = player:getModData()
            -- 症状・Torso 感染は先頭で必ず適用（後続の距離計算 / UpdateMutation で例外が出ても一度は走る）
            if modData and NE.ApplySymptoms then
                NE.ApplySymptoms(player, modData)
            end
            pcall(function()
                if not modData then
                    return
                end
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
            end)
        end
    end
    NE.SyncEvolvedMovementLockGlobally()
end

-- イベント登録
Events.EveryOneMinute.Add(OnEveryOneMinute)

-- --------------------------------------------------------------------------
-- B42 健康パネル: ISHealthPanel.render（x=10,y=12、Small、黒影 1.0、前景 alpha=0.9）
-- --------------------------------------------------------------------------
local NE_HEALTH_MUTATION_TEXT_X = 10
local NE_HEALTH_MUTATION_TEXT_Y = 12
local NE_HEALTH_MUTATION_TEXT_ALPHA = 0.9

--- パーツ B の色。NE.GetMutationSpeechTier の tier 名のみで分岐（数値閾値の二重定義を避ける）。
---@param mut number
---@return number, number, number
local function NE_HealthPanelMutationTextRgb(mut)
    if not NE.GetMutationSpeechTier then
        return 1, 1, 1
    end
    local tier = NE.GetMutationSpeechTier(tonumber(mut) or 0)
    if tier == "EVOLVED" then
        return 1, 0, 0
    end
    if tier == "Critical" then
        return 0.75, 1, 0.35
    end
    if tier == "Danger" then
        return 0.45, 0.88, 1
    end
    if tier == "Unstable" then
        return 1, 1, 1
    end
    return 1, 1, 1
end

local function NE_InstallHealthPanelMutationRender()
    local ISHealthPanel = rawget(_G, "ISHealthPanel")
    if not ISHealthPanel then
        return false
    end
    if ISHealthPanel.NE_Original_render then
        return true
    end
    if type(ISHealthPanel.render) ~= "function" then
        return false
    end

    ISHealthPanel.NE_Original_render = ISHealthPanel.render
    ISHealthPanel.render = function(self)
        local orig = ISHealthPanel.NE_Original_render
        if type(orig) == "function" then
            pcall(function()
                orig(self)
            end)
        end
        pcall(function()
            if NE.Switches and NE.Switches.EnableMutation == false then
                return
            end
            if self == nil or self.character == nil then
                return
            end
            local pl = self.character
            if type(pl.getModData) ~= "function" then
                return
            end
            local md = nil
            local okMd, v = pcall(function()
                ---@diagnostic disable-next-line: undefined-field
                return pl:getModData()
            end)
            if not okMd then
                return
            end
            md = v
            local mut = (md and tonumber(md.NE_MutationLevel)) or 0

            local UIFont = rawget(_G, "UIFont")
            local fontSmall = UIFont and UIFont.Small
            if type(self.drawText) ~= "function" or not fontSmall then
                return
            end

            local partA = getText("UI_NE_Health_Mutation_Title") .. " : "
            local partB = ""
            if NE.GetMutationSeverityText then
                partB = NE.GetMutationSeverityText(mut) or ""
            end
            local partC = " ]"

            local tm = getTextManager and getTextManager() or nil
            local function neMeasureX(str)
                if not tm or type(tm.MeasureStringX) ~= "function" or str == nil or str == "" then
                    return 0
                end
                local okM, w = pcall(function()
                    ---@diagnostic disable-next-line: undefined-field
                    return tm:MeasureStringX(fontSmall, str)
                end)
                if okM and type(w) == "number" then
                    return w
                end
                return 0
            end

            local function neDrawTextWithShadow(str, x, y, r, g, b, a)
                if str == nil or str == "" then
                    return
                end
                self:drawText(str, x + 1, y + 1, 0, 0, 0, 1, fontSmall)
                self:drawText(str, x, y, r, g, b, a, fontSmall)
            end

            local x0 = NE_HEALTH_MUTATION_TEXT_X
            local y0 = NE_HEALTH_MUTATION_TEXT_Y
            local aText = NE_HEALTH_MUTATION_TEXT_ALPHA

            neDrawTextWithShadow(partA, x0, y0, 1, 1, 1, aText)
            local wA = neMeasureX(partA)
            local xB = x0 + wA
            local rr, gg, bb = NE_HealthPanelMutationTextRgb(mut)
            neDrawTextWithShadow(partB, xB, y0, rr, gg, bb, aText)
            local wB = neMeasureX(partB)
            local xC = x0 + wA + wB
            neDrawTextWithShadow(partC, xC, y0, 1, 1, 1, aText)
        end)
    end

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "ISHealthPanel.render:MUTATION_TEXT:HOOKED", "INFO")
    end
    return true
end

pcall(NE_InstallHealthPanelMutationRender)
Events.OnGameBoot.Add(function()
    pcall(NE_InstallHealthPanelMutationRender)
end)
Events.OnGameStart.Add(function()
    NE.SyncEvolvedMovementLockGlobally()
    NE_RegisterMutationSpeedOnPlayerUpdateOnce()
    pcall(NE_InstallHealthPanelMutationRender)
end)

-- 2. 完了ログ (INFO)
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "Load:DONE", "INFO")
end

Events.OnTick.Add(checkHiroReminder)
