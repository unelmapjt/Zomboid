if not NE then NE = {} end

---@class NE_Hotspot
---@field x number
---@field y number
---@field z number
---@field strength number
---@field cap number
---@field type string

-- 震源地レジストリ (設計書 §4.5 準拠)
NE.HotspotRegistry = {
    -- Origin (Z = -17: 最深部最終ゴール)
    { x = 5573, y = 12432, z = -17, strength = 2.5, cap = 1.0, type = "Origin" },

    -- Tier 1 (4つの鍵の所在地)
    { x = 9965, y = 12623, z = -4,  strength = 2.0, cap = 1.0, type = "Tier1" }, -- Key 1: March Ridge B4
    { x = 6500, y = 5298,  z = -1,  strength = 1.8, cap = 1.0, type = "Tier1" }, -- Key 2: Riverside Bank B1
    { x = 2232, y = 6403,  z = -2,  strength = 1.7, cap = 1.0, type = "Tier1" }, -- Key 3: Brandenburg B2
    { x = 7647, y = 11859, z = -1,  strength = 1.6, cap = 1.0, type = "Tier1" }, -- Key 4: Rosewood Prison B1

    -- Tier 2 (都市中心部: 地表 Z=0)
    { x = 10640, y = 9770, z = 0,   strength = 1.2, cap = 0.75, type = "Tier2" }, -- Muldraugh Central
    { x = 6380, y = 5240,  z = 0,   strength = 1.1, cap = 0.75, type = "Tier2" }, -- Riverside Center
    { x = 8140, y = 11460, z = 0,   strength = 1.0, cap = 0.75, type = "Tier2" }, -- Rosewood Center
    { x = 11860, y = 6870, z = 0,   strength = 1.1, cap = 0.75, type = "Tier2" }, -- West Point Center
    { x = 12400, y = 3100, z = 0,   strength = 1.2, cap = 0.75, type = "Tier2" }, -- LV Downtown
    { x = 12500, y = 4100, z = 0,   strength = 1.0, cap = 0.75, type = "Tier2" }, -- LV Checkpoint

    -- Tier 3 (主要施設・密集地: 地表 Z=0)
    { x = 13700, y = 1300,  z = 0,  strength = 0.8, cap = 0.4, type = "Tier3" }, -- Grand Ohio Mall
    { x = 11700, y = 9200,  z = 0,  strength = 0.7, cap = 0.4, type = "Tier3" }, -- Crossroads Mall
    { x = 12585, y = 3600,  z = 0,  strength = 0.8, cap = 0.4, type = "Tier3" }, -- St. Peregrin Hosp
    { x = 11900, y = 6930,  z = 0,  strength = 0.6, cap = 0.4, type = "Tier3" }, -- WP Medical
    { x = 10050, y = 12700, z = 0,  strength = 0.6, cap = 0.4, type = "Tier3" }, -- MR CC
    { x = 14100, y = 3700,  z = 0,  strength = 0.8, cap = 0.4, type = "Tier3" }, -- Power Plant
    { x = 2200, y = 6400,  z = 0,  strength = 0.7, cap = 0.4, type = "Tier3" }, -- Brandenburg Area
}

-- 内部キャッシュ（前回の計算結果を保持し、同一タイルの重複計算を回避）
local _cacheX, _cacheY, _cacheZ, _cacheMult = -1, -1, -1, 0

---プレイヤー座標(XYZ)から現在の汚染倍率(ZoneMultiplier)を算出する (設計書 §4.5, §4.6)
---@param x number プレイヤーX
---@param y number プレイヤーY
---@param z number プレイヤーZ
---@return number zoneMultiplier 最終的な強度倍率 (0.2 - 2.5)
function NE.GetZoneMultiplier(x, y, z)
    -- nil 防御: 引数が不正なら最小値を返す
    if not x or not y or not z then return 0.2 end

    -- タイル単位でのキャッシュ判定
    local floorX, floorY, floorZ = math.floor(x), math.floor(y), math.floor(z)
    if floorX == _cacheX and floorY == _cacheY and floorZ == _cacheZ then
        return _cacheMult
    end

    -- 生存日数の取得
    local survivalDays = (NE.GetCurrentDay and NE.GetCurrentDay()) or 1

    -- 特殊判定: B10〜B17深層は定数扱いの最大汚染 (§4.5)
    if floorZ <= -10 then
        local dxOrig, dyOrig = floorX - 5573, floorY - 12432
        if (dxOrig * dxOrig + dyOrig * dyOrig) < 2500 then -- 半径50タイル以内
            _cacheX, _cacheY, _cacheZ, _cacheMult = floorX, floorY, floorZ, 2.5
            return 2.5
        end
    end

    local maxFoundToxicity = 0.2
    local expansionRadius = 80.0 * survivalDays -- 汚染半径の拡大 (§4.6)
    local floorScale = 5.0 -- 1階層につき水平5タイル分の減衰

    for _, hotspot in ipairs(NE.HotspotRegistry) do
        local dx = floorX - hotspot.x
        local dy = floorY - hotspot.y
        local dz = (floorZ - hotspot.z) * floorScale
        
        -- 3D距離計算
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist < expansionRadius then
            local rawTox = (1.0 - (dist / expansionRadius)) * hotspot.strength
            
            -- 上限 (Cap) 適用
            if rawTox > (hotspot.cap * hotspot.strength) then
                rawTox = hotspot.cap * hotspot.strength
            end

            if rawTox > maxFoundToxicity then
                maxFoundToxicity = rawTox
            end
        end
    end

    -- キャッシュを更新して返却
    _cacheX, _cacheY, _cacheZ, _cacheMult = floorX, floorY, floorZ, maxFoundToxicity
    return maxFoundToxicity
end
