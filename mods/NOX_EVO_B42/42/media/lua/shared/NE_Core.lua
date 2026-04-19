---@class NE
NE = NE or {}
NE.Version = "0.0.1"

-- --------------------------------------------------------------------------
-- NE_Core: サンドボックススイッチ・グローバル定数
-- --------------------------------------------------------------------------

--- 機能スイッチ（サンドボックス設定と同期される）
NE.Switches = {
    EnableMutation = true,
    EnableToxicity = true,
    DebugLog       = true,
}

--- サンドボックス変数からスイッチ値を読み込んで同期する
function NE.refreshSandboxSwitches()
    if not SandboxVars then return end
    local sv = SandboxVars.NOX_EVO or SandboxVars.NOX_EVO_B42
    if type(sv) ~= "table" then return end
    if sv.EnableMutation ~= nil then NE.Switches.EnableMutation = sv.EnableMutation end
    if sv.EnableToxicity ~= nil then NE.Switches.EnableToxicity = sv.EnableToxicity end
    if sv.DebugLog       ~= nil then NE.Switches.DebugLog       = sv.DebugLog       end
end

--- 起動時の診断情報を Z_TRACER へ出力する
function NE.emitModuleDiagnostics()
    if Z_TRACER and Z_TRACER.EmitTrace then
        local m = NE.Switches.EnableMutation and "ON" or "OFF"
        local t = NE.Switches.EnableToxicity and "ON" or "OFF"
        local d = NE.Switches.DebugLog       and "ON" or "OFF"
        Z_TRACER.EmitTrace(
            "NE_DIAG", "NE_Core",
            "EnableMutation=" .. m .. "|EnableToxicity=" .. t .. "|DebugLog=" .. d,
            "INFO"
        )
    end
end

-- --------------------------------------------------------------------------
-- 設計書 4.1 / 4.7 / 4.8.1: グローバル定数 (NE.Config)
-- --------------------------------------------------------------------------
NE.Config = {
    BaseRate     = 0.5,    -- 変異度の1分ごとの基礎上昇率 (設計書 4.8.1)
    MaxMutation  = 100.0,  -- 変異度の最大値 (設計書 4.1)
    RecoveryRate = -0.005, -- 自然回復率 (設計書 4.1)
    SleepMult    = 5.0,    -- 睡眠時の回復倍率 (設計書 4.1)

    -- 設計書 4.7: 室内汚染の状態ごとの流入係数
    LocMult = {
        Open    = 1.0,  -- 屋外 / 開放空間
        Partial = 0.7,  -- 一般室内
        Sealed  = 0.3,  -- 密閉施設
    },

    -- 設計書 4.10: ガスマスクの防護性能
    MaskMult = {
        GoodMask   = 0.1,  -- 正常
        BrokenMask = 0.8,  -- 破損
        NoMask     = 3.0,  -- 未装着
    },

    -- 設計書 4.6: 汚染拡大速度 (タイル/日)
    ExpansionRate = 80.0,
}

-- --------------------------------------------------------------------------
-- 毒性計算ロジックは NE_HotspotManager.lua に移行済み。
-- --------------------------------------------------------------------------

--- 現在の生存日数を取得
function NE.GetCurrentDay()
    local modData = getGameTime():getModData()
    return modData.NE_SurvivalDays or 1
end

-- --------------------------------------------------------------------------
-- 設計書 11.1: フェーズ管理
-- --------------------------------------------------------------------------

--- 現在のフェーズ倍率 (PhaseMult) を返す
function NE.GetPhaseMult()
    local day = NE.GetCurrentDay()
    if day <= 15 then return 1.0 end
    if day <= 35 then return 1.5 end
    return 2.5
end

-- --------------------------------------------------------------------------
-- 初期化ロジック
-- --------------------------------------------------------------------------

--- ワールド ModData の初期化
function NE.InitWorldData()
    local modData = getGameTime():getModData()
    modData.NE_SurvivalDays = modData.NE_SurvivalDays or 1
    modData.NE_Phase        = modData.NE_Phase        or 1

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "World", "InitWorldData:OK", "INFO")
    end
end

--- プレイヤー個別永続データの初期化
function NE.InitPlayerData(player)
    if not player then return end
    local md = player:getModData()
    if md.NE_MutationLevel == nil then md.NE_MutationLevel = 0.0 end

    if NE.Switches.DebugLog and Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "Player",
            string.format("InitPlayerData:OK|Mutation:%.1f", md.NE_MutationLevel),
            "DEBUG"
        )
    end
end

-- --------------------------------------------------------------------------
-- イベント登録
-- --------------------------------------------------------------------------
local function NE_onGameStart()
    NE.refreshSandboxSwitches()
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "NE_Core", "Bootstrap:refreshSandboxSwitches:OK", "INFO")
    end
    NE.emitModuleDiagnostics()
end

local function NE_onCreatePlayer(playerIndex, player)
    NE.InitPlayerData(player)
end

Events.OnGameStart.Add(NE_onGameStart)
Events.OnCreatePlayer.Add(NE_onCreatePlayer)
