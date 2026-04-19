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

    -- フェーズ遷移: サンドボックス「空爆までの猶予日数」に対する比率 (30% / 70% / 空爆前 / 審判)
    local noxSv = SandboxVars and (SandboxVars.NOX_EVOLVED or SandboxVars.NOX_EVO_B42 or SandboxVars.NOX_EVO)
    local sandboxLimit = 50
    if type(noxSv) == "table" and noxSv.DaysToAirstrike then
        sandboxLimit = noxSv.DaysToAirstrike
    end
    sandboxLimit = math.max(7, math.min(365, sandboxLimit))

    local newPhase
    if currentDay <= math.floor(sandboxLimit * 0.3) then
        newPhase = 1
    elseif currentDay <= math.floor(sandboxLimit * 0.7) then
        newPhase = 2
    elseif currentDay < sandboxLimit then
        newPhase = 3
    else
        newPhase = 4
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
