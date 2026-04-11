---@class NE
NE = NE or {}
NE.Version = "0.0.1"

-- DOC.md に基づくグローバル定数
NE.Config = {
    BaseRate = 0.05,      -- 1分ごとの基礎上昇率 (10倍速)
    MaxPollution = 100,   -- 汚染度の最大値 (100%)
    RecoveryRate = -0.005,-- 安全圏での自然回復率 (1分ごと)
    SleepMult = 5.0,      -- 睡眠時の回復倍率
    
    -- 場所による倍率
    LocMult = {
        Outdoor = 0.75,           -- 屋外 (拡散・希釈)
        ResearchFacility = 1.5,    -- 研究・軍事施設内 (密閉・停滞)
        GeneralIndoors = 1.0       -- 一般家屋
    },
    
    -- ガスマスクの防護倍率
    MaskMult = {
        GoodMask = 0.1,    -- マスク装着中（耐久あり）
        BrokenMask = 0.8,  -- マスク装着中（耐久0）
        NoMask = 3.0       -- マスク未装着
    },
    
    -- 汚染支配域の拡大速度（1日あたりのタイル数）
    ExpansionRate = 80.0
}

-- ウィルス震源地 (ホットスポット) リスト
-- strength: 汚染強度倍率
-- cap: その地点が及ぼす最大汚染係数 (0.0 - 1.0)
NE.Hotspots = {
    -- Tier 1: 極大汚染源 (軍事・最密集地) - 3箇所
    { name = "RESEARCH_ORIGIN", x = 5569, y = 12432, z = -17, strength = 2.0, cap = 1.0 }, -- 地下17階軍事基地 (震源地)
    { name = "LOUISVILLE_GATE", x = 13500, y = 2800, z = 0, strength = 1.8, cap = 1.0 }, -- ルイビル検問所
    { name = "ROSEWOOD_PRISON", x = 7650, y = 11800, z = 0, strength = 2.0, cap = 1.0 }, -- ローズウッド刑務所

    -- Tier 2: B42 都市化された密集施設 (z = 0 は地上階)
    { name = "LOUISVILLE_DOWNTOWN", x = 12500, y = 3500, z = 0, strength = 1.5, cap = 0.8 },
    { name = "MULDRAUGH_PD_STRIP", x = 10640, y = 9425, z = 0, strength = 1.3, cap = 0.5 },
    { name = "WESTPOINT_PD", x = 11904, y = 6939, z = 0, strength = 1.4, cap = 0.6 },
    { name = "VALLEY_STATION_MALL", x = 13800, y = 5800, z = 0, strength = 1.5, cap = 0.7 },
    { name = "MARCH_RIDGE_DORM", x = 7650, y = 13745, z = 0, strength = 1.2, cap = 0.5 },
    { name = "RIVERSIDE_PD", x = 6370, y = 5262, z = 0, strength = 1.1, cap = 0.5 },
    { name = "EKRON_DOWNTOWN", x = 7100, y = 8100, z = 0, strength = 1.0, cap = 0.4 },
    { name = "DIXIE_CROSSROADS", x = 11600, y = 8800, z = 0, strength = 1.0, cap = 0.4 },

    -- Tier 3: 地域密度拠点
    { name = "LD_HOSPITAL", x = 13300, y = 3500, z = 0, strength = 0.9, cap = 0.3 },
    { name = "LD_CINEMA", x = 12200, y = 3200, z = 0, strength = 0.8, cap = 0.25 },
    { name = "MULD_CORNER", x = 10800, y = 9800, z = 0, strength = 0.7, cap = 0.25 },
    { name = "WP_SCHOOL", x = 12050, y = 6700, z = 0, strength = 0.8, cap = 0.25 },
    { name = "RW_PD", x = 8136, y = 11736, z = 0, strength = 1.0, cap = 0.3 },
    { name = "RS_POLICE", x = 6400, y = 5350, z = 0, strength = 0.7, cap = 0.25 },
    { name = "DIXIE_TRAILERS", x = 11500, y = 8700, z = 0, strength = 0.7, cap = 0.25 },
    { name = "PONY_ROAM_O", x = 10300, y = 12500, z = 0, strength = 0.6, cap = 0.25 },
    { name = "WP_GIGAMART", x = 11900, y = 6900, z = 0, strength = 0.8, cap = 0.25 },
    { name = "RS_GIGAMART", x = 6300, y = 5100, z = 0, strength = 0.8, cap = 0.25 },
    { name = "MULD_WAREHOUSE", x = 10600, y = 10000, z = 0, strength = 0.6, cap = 0.25 },
    { name = "RS_COUNTRYCLUB", x = 5800, y = 6200, z = 0, strength = 0.7, cap = 0.25 },
    { name = "RW_HOSPITAL", x = 8100, y = 11300, z = 0, strength = 0.7, cap = 0.25 },
    { name = "RS_FACTORY", x = 5500, y = 5900, z = 0, strength = 0.6, cap = 0.25 },
    { name = "LOUISVILLE_STADIUM", x = 12500, y = 2000, z = 0, strength = 1.0, cap = 0.4 }
}

--- 現在の生存日数を取得 (ModData参照)
---@return number
function NE.GetCurrentDay()
    if not SandboxVars then return 1 end
    local modData = getGameTime():getModData()
    return modData.NE_SurvivalDays or 1
end

--- 指定座標(3D)の汚染係数を算出
---@param x number
---@param y number
---@param z number
---@return number intensity 汚染強度 (0.0 - 1.0)
---@return number distance 平面上の最短距離
function NE.CalculateViralFactor(x, y, z)
    local maxIntensity = 0
    local minDistance = 999999
    local currentDay = NE.GetCurrentDay()
    
    -- 当日の基礎拡大半径 (1日目から 3x3 の 9タイルをカバーするよう +1.5 する)
    local currentRadius = (currentDay - 1) * NE.Config.ExpansionRate + 1.5

    for _, hotspot in ipairs(NE.Hotspots) do
        -- 2D平面距離計算
        local dx = x - hotspot.x
        local dy = y - hotspot.y
        local dist2D = math.sqrt(dx*dx + dy*dy)
        
        -- 最短距離（平面）の更新
        if dist2D < minDistance then minDistance = dist2D end
        
        -- 各震源地ごとの影響半径
        local effectiveRadius = currentRadius * hotspot.strength
        
        -- 半径内にいるかチェック (等号を含めて 1タイルの場合もカバー)
        if dist2D <= effectiveRadius then
            -- 地点(平面)での基礎強度を計算 (1.0 ➔ 0.0)
            local baseIntensity = 1.0 - (dist2D / effectiveRadius)
            
            -- ホットスポット固有の上限 (Cap) を適用
            baseIntensity = math.min(baseIntensity, hotspot.cap)
            
            -- 【階層減衰ロジック】 1階層離れるごとに 0.8倍
            local floorDiff = math.abs(z - (hotspot.z or 0))
            local finalIntensity = baseIntensity * (0.8 ^ floorDiff)
            
            if finalIntensity > maxIntensity then
                maxIntensity = finalIntensity
            end
        end
    end

    return maxIntensity, minDistance
end

-- 負荷軽減用キャッシュ
NE.CachedX = -1
NE.CachedY = -1
NE.CachedZ = -1
NE.CachedFactor = 0

--- 座標(x,y,z)の汚染係数を取得 (キャッシュ機能付き)
---@param x number
---@param y number
---@param z number
---@return number intensity
function NE.GetViralFactor(x, y, z)
    -- 前回と同じタイル（整数値）であればキャッシュを返す
    local floorX = math.floor(x)
    local floorY = math.floor(y)
    local floorZ = math.floor(z)

    if floorX == NE.CachedX and floorY == NE.CachedY and floorZ == NE.CachedZ then
        return NE.CachedFactor
    end

    -- 座標が変化した場合は再計算
    local factor, dist = NE.CalculateViralFactor(floorX, floorY, floorZ)
    
    -- キャッシュの更新
    NE.CachedX = floorX
    NE.CachedY = floorY
    NE.CachedZ = floorZ
    NE.CachedFactor = factor

    return factor
end

--- ワールドModDataの初期化 (生存日数, フェーズ)
function NE.InitWorldData()
    local modData = getGameTime():getModData()
    
    -- 生存日数が未設定なら 1 日目に設定
    modData.NE_SurvivalDays = modData.NE_SurvivalDays or 1
    
    -- 進行フェーズ(0:開始, 1:変異開始, 2:終末)が未設定なら 0 に設定
    modData.NE_Phase = modData.NE_Phase or 0
    
    print("NOX: EVOLVED - ワールドデータが初期化されました。生存日数: " .. modData.NE_SurvivalDays)
end

--- プレイヤーごとの個別永続データの初期化
---@param player IsoPlayer
function NE.InitPlayerData(player)
    if not player then return end
    local modData = player:getModData()
    
    -- 汚染度 (0.0 - 100.0) が未設定なら 0 で初期化
    modData.NE_PollutionLevel = modData.NE_PollutionLevel or 0
    
    -- 進化エネルギー/ポイント (将来的な拡張用)
    modData.NE_MutationPoints = modData.NE_MutationPoints or 0
    
    print("NOX: EVOLVED - プレイヤー個別の変数を初期化しました: " .. player:getFullName())
end

-- 初期化フラグ
NE.isInitialized = false

--- コアシステムの初期化
function NE.init()
    if NE.isInitialized then return end
    
    -- 将来的な初期化ロジックをここに記述
    
    NE.isInitialized = true
    print("NOX: EVOLVED - コアシステムが初期化されました。")
end

-- コンソールにロード完了を表示
print("NOX: EVOLVED - NE_Core がロードされました。バージョン: " .. NE.Version)
