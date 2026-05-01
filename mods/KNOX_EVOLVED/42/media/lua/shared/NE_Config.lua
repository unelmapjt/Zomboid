--- NOX: EVOLVED Global Configuration
--- Role: Centralized constants and Sandbox synchronization (SSoT)
--- NE_Core.lua 削除後の統合先: NE.Switches / InitPlayerData / GetCurrentDay / GetPhaseMult
--- --------------------------------------------------------------------------

NE = NE or {}
-- NE.Switches: 他スクリプトで一部だけ設定されていてもデフォルトを維持（NE_Core 相当）
NE.Switches = NE.Switches or {}
if NE.Switches.DebugLog == nil then
    NE.Switches.DebugLog = true
end
if NE.Switches.EnableMutation == nil then
    NE.Switches.EnableMutation = true
end
NE.Config = NE.Config or {}

-- 1. 基本定数 (Design §4.1, §4.13)
NE.Config.BaseRate     = 0.5      -- 基礎変異上昇率 (毎分)
NE.Config.MaxMutation  = 100.0    -- 変異度上限
NE.Config.RecoveryRate = -0.005   -- 自然浄化率 (安全圏)
NE.Config.SleepMult    = 5.0      -- 睡眠時の倍率

-- 2. ロケーション倍率 (Design §4.7)
NE.Config.LocMult = {
    Open    = 1.0,   -- 屋外
    Partial = 0.7,   -- 一般室内
    Sealed  = 0.3    -- 密閉施設（研究所・地下・車両）
}

-- 室内の NE_CurrentInternalLocMult が TargetLocMult に近づく目安時間（ゲーム内・分）
-- Open 目標: 約 5 分で外部相当 / Partial・Sealed 目標: 約 30 分で到達（1 分あたり (target-current)/M）
NE.Config.LocMultConvergenceMinutes = {
    Open    = 5,
    Partial = 30,
    Sealed  = 30,
}

-- 3. ガスマスク倍率 (Design §4.10)
NE.Config.MaskMult = {
    GoodMask   = 0.1,   -- 良好 (B41初期値0.0だがB42では0.1に調整)
    BrokenMask = 0.8,   -- 損壊（フィルター切れ/穴）
    NoMask     = 3.0    -- 未装着（汚染地帯では致命的）
}

-- 4. 環境・世界設定
NE.Config.ExpansionRate = 80.0    -- 汚染半径の拡大速度 (設計 §4.6)

-- ゾーン倍率: Danger→Safe 改善時のヒステリシス（設計書 §4.10、ゲーム内・分）
NE.Config.ZoneHysteresisMinutes = 30

--------------------------------------------------------------------------
-- Sandbox Sync Logic (SSoT)
-- サンドボックス設定の変更を NE.Config に反映させる
--------------------------------------------------------------------------
function NE.refreshSandboxSwitches()
    local sb = SandboxVars.KNOX_EVOLVED or SandboxVars.NOX_EVO or {}
    
    if sb.MutationBaseRate then
        NE.Config.BaseRate = sb.MutationBaseRate
    end
    -- 必要に応じて他の設定もここで同期可能
    
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "Config", 
            "Refresh:OK|BaseRate:" .. tostring(NE.Config.BaseRate), "INFO")
    end
end

-- 初期化トレース
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "Config", "Load:OK", "INFO")
end

-- グローバル初期化時に一度実行
NE.refreshSandboxSwitches()

--------------------------------------------------------------------------
-- NE_Core.lua 相当: ワールド modData 参照（NE_Mutation / NE_PlayerManager 等）
--------------------------------------------------------------------------

--- 生存日数（NE_WorldManager が getGameTime():getModData().NE_SurvivalDays に同期）
---@return number
function NE.GetCurrentDay()
    local gt = getGameTime()
    if not gt then
        return 1
    end
    local modData = gt:getModData()
    if not modData then
        return 1
    end
    local d = modData.NE_SurvivalDays
    if d == nil or type(d) ~= "number" then
        return 1
    end
    return d
end

--- 汚染フェーズ倍率（NE_WorldManager が getGameTime():getModData().NE_Phase を設定）
--- Phase1=1.0 / Phase2=1.5 / Phase3=2.5（Phase4 以降は Phase3 と同倍率）
---@return number
function NE.GetPhaseMult()
    local gt = getGameTime()
    if not gt then
        return 1.0
    end
    local modData = gt:getModData()
    if not modData then
        return 1.0
    end
    local phase = modData.NE_Phase
    if phase == nil or type(phase) ~= "number" then
        return 1.0
    end
    if phase <= 1 then
        return 1.0
    end
    if phase == 2 then
        return 1.5
    end
    return 2.5
end

--- プレイヤーの初期 ModData をセットアップ（NE_MutationLevel 以外の nil キーのみ埋める。変異度は NE_StartScene で明示設定）
---@param player IsoPlayer
function NE.InitPlayerData(player)
    if not player then
        return
    end
    local modData = player:getModData()
    if not modData then
        return
    end
    if modData.NE_CurrentInternalLocMult == nil then
        modData.NE_CurrentInternalLocMult = 1.0
    end
    if modData.NE_LastMutationUpdateTimestamp == nil then
        local gt = getGameTime()
        modData.NE_LastMutationUpdateTimestamp = gt and (gt:getWorldAgeHours() * 60) or 0
    end
    if modData.NE_HiroReminderCount == nil then
        modData.NE_HiroReminderCount = 0
    end
    if modData.NE_HiroRemindersSilenced == nil then
        modData.NE_HiroRemindersSilenced = false
    end
end
