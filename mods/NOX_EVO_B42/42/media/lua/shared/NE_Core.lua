---@class NE
NE = NE or {}
NE.Version = "0.0.1"

-- --------------------------------------------------------------------------
-- NE_Core: サンドボックススイッチ・グローバル定数・Z_System 連携（生 print 禁止）
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
    BaseRate     = 0.5,    -- 変異度の1分ごとの基礎上昇率 (設計書 4.8.1: 0.5/game-min)
    MaxMutation  = 100.0,  -- 変異度の最大値 (設計書 4.1)
    RecoveryRate = -0.005, -- 安全圏での1分ごとの自然回復率 (設計書 4.1)
    SleepMult    = 5.0,    -- 睡眠時の回復倍率 (設計書 4.1)

    -- 設計書 4.7: 室内密閉状態ごとのウイルス流入係数
    -- 設計書 4.8.1 シミュレーション検証済み:
    --   Zone1/Open(1.0):   0.5*1.0*2.0 = 1.0/min → 100分で100% ✓
    --   Zone3/Sealed(0.3): 0.5*0.3*1.0 = 0.15/min → 666分で100% ✓
    LocMult = {
        Open    = 1.0,  -- 屋外 / 開放空間 (窓・ドア開放)
        Partial = 0.7,  -- 一般室内 (半密閉: 壁・屋根あり、開口部あり)
        Sealed  = 0.3,  -- 密閉施設 (研究所・軍・刑務所: 全開口部閉鎖)
    },

    -- 設計書 4.10: ガスマスクの防護性能
    MaskMult = {
        GoodMask   = 0.1,  -- NE_FilterLife ≥ 1 のマスク装着中
        BrokenMask = 0.8,  -- NE_FilterLife = 0 のマスク、または簡易防護
        NoMask     = 3.0,  -- 未装着 (変異速度 3倍)
    },

    -- 設計書 4.6 / 12.2: 侵食拡大速度 (タイル/日)
    ExpansionRate = 80.0,
}

-- --------------------------------------------------------------------------
-- 設計書 4.8: 5段階ゾーンシステム定数
-- --------------------------------------------------------------------------
-- 距離割合 D (dist2D / effectiveRadius) → ZoneMultiplier マッピング
NE.ZoneThresholds  = { 0.20, 0.40, 0.60, 0.80, 1.00 }
NE.ZoneMultipliers = { 2.0,  1.5,  1.0,  0.5,  0.2  }

-- --------------------------------------------------------------------------
-- 設計書 4.5: ウィルス震源地リスト (全 25 箇所)
-- strength: 拡大半径倍率  /  cap: 最大ゾーン強度上限 (0.0 - 1.0)
-- --------------------------------------------------------------------------
NE.Hotspots = {
    -- Origin (根源): 軍事研究施設 B17 地下最深部 — Day 1 から Toxicity = 1.0 固定
    { name = "RESEARCH_ORIGIN",     x = 5569,  y = 12432, z = -17, strength = 2.5, cap = 1.0 },

    -- Tier 1 (軍事): 4 箇所
    { name = "LOUISVILLE_GATE",     x = 13500, y = 2800,  z = 0,   strength = 2.0, cap = 1.0 },
    { name = "ROSEWOOD_PRISON",     x = 7650,  y = 11800, z = 0,   strength = 1.8, cap = 1.0 },
    { name = "MARCH_RIDGE_CAMP",    x = 7650,  y = 13745, z = 0,   strength = 1.6, cap = 1.0 },
    { name = "CROSSROADS_MILITARY", x = 11600, y = 8800,  z = 0,   strength = 1.6, cap = 1.0 },

    -- Tier 2 (都市部): 5 箇所
    { name = "LOUISVILLE_DOWNTOWN", x = 12500, y = 3500,  z = 0,   strength = 1.2, cap = 0.75 },
    { name = "MULDRAUGH_PD_STRIP",  x = 10640, y = 9425,  z = 0,   strength = 1.1, cap = 0.75 },
    { name = "RIVERSIDE_PD",        x = 6370,  y = 5262,  z = 0,   strength = 1.0, cap = 0.75 },
    { name = "WESTPOINT_PD",        x = 11904, y = 6939,  z = 0,   strength = 1.1, cap = 0.75 },
    { name = "VALLEY_STATION_MALL", x = 13800, y = 5800,  z = 0,   strength = 1.2, cap = 0.75 },

    -- Tier 3 (密集地): 16 箇所
    { name = "LD_HOSPITAL",         x = 13300, y = 3500,  z = 0,   strength = 0.8, cap = 0.40 },
    { name = "LD_CINEMA",           x = 12200, y = 3200,  z = 0,   strength = 0.7, cap = 0.40 },
    { name = "MULD_CORNER",         x = 10800, y = 9800,  z = 0,   strength = 0.6, cap = 0.40 },
    { name = "WP_SCHOOL",           x = 12050, y = 6700,  z = 0,   strength = 0.7, cap = 0.40 },
    { name = "RW_PD",               x = 8136,  y = 11736, z = 0,   strength = 0.8, cap = 0.40 },
    { name = "RS_POLICE",           x = 6400,  y = 5350,  z = 0,   strength = 0.6, cap = 0.40 },
    { name = "DIXIE_TRAILERS",      x = 11500, y = 8700,  z = 0,   strength = 0.6, cap = 0.40 },
    { name = "PONY_ROAM_O",         x = 10300, y = 12500, z = 0,   strength = 0.5, cap = 0.40 },
    { name = "WP_GIGAMART",         x = 11900, y = 6900,  z = 0,   strength = 0.7, cap = 0.40 },
    { name = "RS_GIGAMART",         x = 6300,  y = 5100,  z = 0,   strength = 0.7, cap = 0.40 },
    { name = "MULD_WAREHOUSE",      x = 10600, y = 10000, z = 0,   strength = 0.5, cap = 0.40 },
    { name = "RS_COUNTRYCLUB",      x = 5800,  y = 6200,  z = 0,   strength = 0.6, cap = 0.40 },
    { name = "RW_HOSPITAL",         x = 8100,  y = 11300, z = 0,   strength = 0.6, cap = 0.40 },
    { name = "RS_FACTORY",          x = 5500,  y = 5900,  z = 0,   strength = 0.5, cap = 0.40 },
    { name = "LOUISVILLE_STADIUM",  x = 12500, y = 2000,  z = 0,   strength = 0.8, cap = 0.40 },
}

-- --------------------------------------------------------------------------
-- 設計書 4.6: 拡大半径と毒性計算
-- --------------------------------------------------------------------------

--- 現在の生存日数を取得 (ModData 参照)
---@return number
function NE.GetCurrentDay()
    local modData = getGameTime():getModData()
    return modData.NE_SurvivalDays or 1
end

--- cap 値から許容される最大 ZoneMultiplier を返す (設計書 4.5 / 4.8)
--- cap=1.0(Tier1) → 2.0, cap=0.75(Tier2) → 1.5, cap≤0.40(Tier3) → 1.0
---@param cap number hotspot の cap 値
---@return number maxZoneMult
local function capToMaxZone(cap)
    if cap >= 1.0  then return 2.0 end
    if cap >= 0.75 then return 1.5 end
    return 1.0
end

-- タイルキャッシュ（シングルプレイ向け高速化: 同一タイルの重複計算防止）
NE._cacheX    = -1
NE._cacheY    = -1
NE._cacheZ    = -1
NE._cacheMult = 0

--- 指定座標の ZoneMultiplier を返す（5段階離散ゾーン + 垂直減衰 + タイルキャッシュ）
--- 設計書 4.8: D=dist2D/effectiveRadius → Zone1(0-20%): 2.0x … Zone5(81-100%): 0.2x
--- 設計書 4.6: 垂直減衰 zoneMult * 0.5^floorDiff
--- 戻り値 0 = 安全圏（どの震源地の圏外）
---@param x number
---@param y number
---@param z number
---@return number zoneMult
function NE.GetZoneMultiplier(x, y, z)
    local floorX = math.floor(x)
    local floorY = math.floor(y)
    local floorZ = math.floor(z)

    if floorX == NE._cacheX and floorY == NE._cacheY and floorZ == NE._cacheZ then
        return NE._cacheMult
    end

    local bestMult   = 0
    local currentDay = NE.GetCurrentDay()
    local baseRadius = (currentDay - 1) * NE.Config.ExpansionRate + 1.5

    for _, hotspot in ipairs(NE.Hotspots) do
        local dx         = floorX - hotspot.x
        local dy         = floorY - hotspot.y
        local dist2D     = math.sqrt(dx * dx + dy * dy)
        local effRadius  = baseRadius * hotspot.strength

        if dist2D <= effRadius then
            -- 距離割合 D → 離散ゾーン倍率
            local D        = dist2D / effRadius
            local zoneMult = 0.2  -- Zone 5 デフォルト
            for i, threshold in ipairs(NE.ZoneThresholds) do
                if D <= threshold then
                    zoneMult = NE.ZoneMultipliers[i]
                    break
                end
            end

            -- hotspot.cap によるゾーン上限適用
            zoneMult = math.min(zoneMult, capToMaxZone(hotspot.cap))

            -- 垂直減衰 (設計書 4.6: 1階層差ごとに 0.5 倍)
            local floorDiff = math.abs(floorZ - (hotspot.z or 0))
            if floorDiff > 0 then
                zoneMult = zoneMult * (0.5 ^ floorDiff)
            end

            if zoneMult > bestMult then
                bestMult = zoneMult
            end
        end
    end

    NE._cacheX    = floorX
    NE._cacheY    = floorY
    NE._cacheZ    = floorZ
    NE._cacheMult = bestMult
    return bestMult
end

-- --------------------------------------------------------------------------
-- 設計書 11.1: フェーズ管理
-- --------------------------------------------------------------------------

--- 現在のフェーズ倍率 (PhaseMult) を返す
--- Phase 1 (Day 1-15): 1.0x / Phase 2 (16-35): 1.5x / Phase 3 (36-49): 2.5x
---@return number phaseMult
function NE.GetPhaseMult()
    local day = NE.GetCurrentDay()
    if day <= 15 then return 1.0 end
    if day <= 35 then return 1.5 end
    return 2.5
end

-- --------------------------------------------------------------------------
-- 初期化ロジック
-- --------------------------------------------------------------------------

--- ワールド ModData の初期化 (生存日数, フェーズ) — OnInitWorld から呼ぶ
function NE.InitWorldData()
    local modData = getGameTime():getModData()
    modData.NE_SurvivalDays = modData.NE_SurvivalDays or 1
    modData.NE_Phase        = modData.NE_Phase        or 1

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "World", "InitWorldData:OK", "INFO")
    end
end

--- プレイヤー個別永続データの初期化
--- 設計書 4.13: OnCreatePlayer でフック。既存データが存在する場合は上書きしない。
---@param player IsoPlayer|nil
function NE.InitPlayerData(player)
    if not player then
        if Z_CORE and Z_CORE.Log then
            Z_CORE.Log("InitPlayerData: player is nil", "NE")
        end
        return
    end
    local md = player:getModData()

    -- 設計書 4.13: 変異度（唯一の主要ゲームメトリクス）
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
-- EveryOneMinute は NE_PlayerManager.lua (client) に一本化。
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
