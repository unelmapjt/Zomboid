--- NOX: EVOLVED Global Configuration
--- Role: Centralized constants and Sandbox synchronization (SSoT)
--- --------------------------------------------------------------------------

NE = NE or {}
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

-- 3. ガスマスク倍率 (Design §4.10)
NE.Config.MaskMult = {
    GoodMask   = 0.1,   -- 良好 (B41初期値0.0だがB42では0.1に調整)
    BrokenMask = 0.8,   -- 損壊（フィルター切れ/穴）
    NoMask     = 3.0    -- 未装着（汚染地帯では致命的）
}

-- 4. 環境・世界設定
NE.Config.ExpansionRate = 80.0    -- 汚染半径の拡大速度 (設計 §4.6)

--------------------------------------------------------------------------
-- Sandbox Sync Logic (SSoT)
-- サンドボックス設定の変更を NE.Config に反映させる
--------------------------------------------------------------------------
function NE.refreshSandboxSwitches()
    local sb = SandboxVars.NOX_EVO_B42 or SandboxVars.NOX_EVO or {}
    
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
