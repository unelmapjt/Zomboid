-- --------------------------------------------------------------------------
-- NE_LoreManager.lua (Client)
-- Role: フェーズ遷移の検知とナラティブ演出（本能テキスト）
-- --------------------------------------------------------------------------

NE = NE or {}

local function OnPhaseShift(newPhase)
    local player = getPlayer()
    if not player then return end

    -- 1. 音の演出 (B42 バニラ音)
    player:playSound("AmbientExplosion")

    -- 2. ナラティブ演出 (Say による独白)
    local textKey = "UI_NE_Phase_" .. tostring(newPhase)
    local text = getText(textKey)
    if text ~= textKey then
        player:say(text)
    end

    -- 3. 構造化ログ
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_LORE", "PhaseShift", "Show:Phase" .. newPhase, "INFO")
    end
end

local function checkPhaseShift()
    -- NE_WorldManager.lua (Server) でセットされるトリガーを監視
    local modData = getGameTime():getModData()
    if not modData then return end

    if modData.NE_PhaseShiftTrigger then
        local newPhase = modData.NE_Phase or 1

        -- クライアント側で演出を実行
        OnPhaseShift(newPhase)

        -- トリガーを消費（リセット）
        modData.NE_PhaseShiftTrigger = false
    end
end

-- サーバー側の判定間隔 (EveryTenMinutes) に合わせて定期チェック
Events.EveryTenMinutes.Add(checkPhaseShift)

-- --------------------------------------------------------------------------
-- 独白（モノローグ）エンジン
-- --------------------------------------------------------------------------
local monologueCooldown = 0

-- B42: stats.health / stats.panic（小文字フィールド）優先。ゲッターはフォールバック。
local function readHealthAndPanicFromStats(stats)
    local health, panic = 1, 0
    if not stats then return health, panic end

    if type(stats.health) == "number" then
        health = stats.health
    elseif stats.getHealth then
        local h = stats:getHealth()
        if type(h) == "number" then health = h end
    elseif type(stats.Health) == "number" then
        health = stats.Health
    end

    if type(stats.panic) == "number" then
        panic = stats.panic
    elseif stats.getPanic then
        local p = stats:getPanic()
        if type(p) == "number" then panic = p end
    elseif type(stats.Panic) == "number" then
        panic = stats.Panic
    end

    return health, panic
end

local function checkMonologue()
    if not SandboxVars then return end
    local noxVars = SandboxVars.NOX_EVO_B42 or SandboxVars.NOX_EVOLVED or SandboxVars.NOX_EVO

    local player = getPlayer()
    if not player or player:isDead() or player:isAsleep() then return end
    
    local modData = player:getModData()
    local mutation = modData.NE_MutationLevel or 0
    local lastMutation = modData.NE_LastMonologueMutation or 0
    modData.NE_LastMonologueMutation = mutation

    -- クールダウン中、あるいは独白（本能Voice）が無効なら終了
    if monologueCooldown > 0 then
        monologueCooldown = monologueCooldown - 1
        return
    end

    if noxVars and noxVars.InstinctVoice == false then return end

    -- 判定開始
    local category = "Mutation"
    local subType  = nil
    local maxIndex = 0
    local sayColor = {r=1, g=1, b=1} -- デフォルト：白

    -- 頻度とクールダウンの動的計算 (変異度が高いほど、意識が混濁しおしゃべりになる)
    -- ベース 10% 成功率、最大 70%
    local triggerChance = 10 + (mutation / 100) * 60
    if ZombRand(100) > triggerChance then return end

    -- A. 正気への復帰判定 (変異度が 5% 以上低下した瞬間)
    if lastMutation > mutation + 5 then
        if ZombRand(100) < 50 then -- 確率を少し上昇
            category, subType, maxIndex = "Recovery", "1", 4
        end
    end

    -- B. 暴走判定 (汚染域)
    local isDangerZone = false
    if modData.NE_LastZoneMult and modData.NE_LastZoneMult > 1.0 then isDangerZone = true end
    
    if not subType and isDangerZone then
        category, subType, maxIndex = "Berserk", "1", 5
        sayColor = {r=0.8, g=0.1, b=0.1} -- 深紅
    end

    -- C. カテゴリ判定 (場所、天候、内省、または変異レベル)
    if not subType then
        local dice = ZombRand(100)
        local stats = player.getStats and player:getStats() or nil
        local health, panic = readHealthAndPanicFromStats(stats)

        -- 1. 場所判定 (15% 優先)
        local square = player:getCurrentSquare()
        if dice < 15 and square then
            local room = square:getRoom()
            if room then
                local roomDef = room:getRoomDef()
                local rName = string.lower(roomDef:getName() or "")
                if string.find(rName, "research") or string.find(rName, "laboratory") or string.find(rName, "hospital") then
                    category, subType, maxIndex = "Loc", "Lab", 2
                elseif string.find(rName, "house") or string.find(rName, "kitchen") or string.find(rName, "bedroom") then
                    category, subType, maxIndex = "Loc", "Home", 1
                end
            end
        end

        -- 2. 特殊状態判定
        if not subType then
            if panic < 10 and ZombRand(100) < 10 then
                category, subType, maxIndex = "Happy", "1", 10
            elseif health < 0.5 or (mutation > 30 and mutation < 60 and ZombRand(100) < 30) then
                category, subType, maxIndex = "Despair", "1", 10
            elseif dice < 25 then
                category, subType, maxIndex = "Memory", "1", 5
            elseif dice < 35 then
                category, subType, maxIndex = "Sensory", "1", 3
            elseif dice < 45 then
                category, subType, maxIndex = "Reflection", "1", 4
            end
            -- 変異段階のセリフ（Clean / Unstable / Danger / Critical / EVOLVED）は
            -- NE_PlayerManager.ApplySymptoms（境界＋クールダウン付き周期）に集約
        end
    end

    -- キーの組み立て
    if not subType then return end

    local index = ZombRand(maxIndex) + 1
    local textKey = ""
    
    if category == "Mutation" or category == "Loc" or category == "Weather" then
        textKey = string.format("UI_NE_Speech_%s_%s_%d", category, subType, index)
    else
        -- Happy, Memory, Reflection, Sensory, Recovery, Berserk, Despair は直接連番
        textKey = string.format("UI_NE_Speech_%s_%d", category, index)
    end

    local text = getText(textKey)

    if text ~= textKey then
        player:Say(text, sayColor.r, sayColor.g, sayColor.b, UIFont.Intermediate, 10, "white")
        
        -- クールダウンも変異度に応じて短縮 (100%付近ではクールダウンなし)
        monologueCooldown = math.max(0, 4 - math.floor(mutation / 20))
        
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_LORE", "Monologue", "Show: " .. textKey, "INFO")
        end
    end
end

Events.EveryTenMinutes.Add(checkMonologue)

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "LoreManager", "Load:OK", "INFO")
end
