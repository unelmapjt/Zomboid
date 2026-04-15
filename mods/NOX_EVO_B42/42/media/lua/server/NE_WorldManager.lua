-- --------------------------------------------------------------------------
-- Path: media/lua/server/NE_WorldManager.lua
-- Role: サーバー側での生存日数管理とワールドModDataの同期
-- --------------------------------------------------------------------------

NE = NE or {}

--- 生存日数の自動インクリメント処理 + フェーズ遷移 (設計書 11.1)
function NE.UpdateSurvivalDays()
    local modData = getGameTime():getModData()
    
    local hours      = math.floor(getGameTime():getWorldAgeHours())
    local currentDay = math.floor(hours / 24) + 1

    if not modData.NE_SurvivalDays or modData.NE_SurvivalDays < currentDay then
        modData.NE_SurvivalDays = currentDay
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_WORLD", "SurvivalDays", "Updated:" .. currentDay, "INFO")
        end
    end

    -- フェーズ遷移判定 (設計書 11.1)
    -- Phase 1: Day 1-15 (1.0x) / Phase 2: Day 16-35 (1.5x) / Phase 3: Day 36-49 (2.5x)
    local newPhase
    if currentDay <= 15 then
        newPhase = 1
    elseif currentDay <= 35 then
        newPhase = 2
    elseif currentDay <= 49 then
        newPhase = 3
    else
        newPhase = 4  -- EndGame
    end

    local prevPhase = modData.NE_Phase or 1
    if newPhase ~= prevPhase then
        modData.NE_Phase = newPhase
        modData.NE_PhaseShiftTrigger = true
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_WORLD", "PhaseShift",
                "Phase:" .. prevPhase .. "->" .. newPhase .. "|Day:" .. currentDay, "INFO")
        end
    end
end

-- 各種イベントへの登録
-- ワールド初期化時にModDataを準備
Events.OnInitWorld.Add(NE.InitWorldData)
-- ゲーム内10分ごとに日数の経過をチェック
Events.EveryTenMinutes.Add(NE.UpdateSurvivalDays)

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "WorldManager", "Load:OK", "INFO")
end
