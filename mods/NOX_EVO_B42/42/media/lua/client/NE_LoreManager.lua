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

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "LoreManager", "Load:OK", "INFO")
end
