if not NE then NE = {} end

-- NE.ContaminationRate = 80.0 (定数)
NE.ContaminationRate = 80.0

---@class NE_Hotspot
---@field x number
---@field y number
---@field z number
---@field strength number
---@field cap number
---@field type string

-- 震源地レジストリ (設計書 §4.5 準拠) — テスト: 単一ホットスポットのみ
NE.HotspotRegistry = {
    -- Test Case: LV Rescue Shelter (Start)
    { x = 15640, y = 3909, z = 0, strength = 0.8, cap = 0.4, type = "Tier3" },
}

-- 内部キャッシュ（前回の計算結果を保持し、同一タイルの重複計算を回避）
local _cacheX, _cacheY, _cacheZ, _cacheMult = -1, -1, -1, 0

---プレイヤー座標(XYZ)から現在の汚染倍率(ZoneMultiplier)を算出する (設計書 §4.5, §4.6)
---@param x number プレイヤーX
---@param y number プレイヤーY
---@param z number プレイヤーZ
---@return number zoneMultiplier 最終的な強度倍率 (0.0 = ホットスポット圏外 … 2.5)
function NE.GetZoneMultiplier(x, y, z)
    -- nil 防御: 引数が不正なら汚染なし（0.0）
    if not x or not y or not z then return 0.0 end

    -- タイル単位でのキャッシュ判定
    local floorX, floorY, floorZ = math.floor(x), math.floor(y), math.floor(z)
    if floorX == _cacheX and floorY == _cacheY and floorZ == _cacheZ then
        return _cacheMult
    end

    -- 生存日数の取得
    local survivalDays = (NE.GetCurrentDay and NE.GetCurrentDay()) or 1

    -- expansionSpeed = SandboxVars.NE.WorldExpansionSpeed (デフォルト 1.0)
    local expansionSpeed = 1.0
    local sb = SandboxVars.KNOX_EVOLVED or SandboxVars.NOX_EVO or {}
    if sb.WorldExpansionSpeed then expansionSpeed = sb.WorldExpansionSpeed end

    -- 特殊判定: B10〜B17深層は定数扱いの最大汚染 (§4.5)
    if floorZ <= -10 then
        local dxOrig, dyOrig = floorX - 5573, floorY - 12432
        if (dxOrig * dxOrig + dyOrig * dyOrig) < 2500 then -- 半径50タイル以内
            _cacheX, _cacheY, _cacheZ, _cacheMult = floorX, floorY, floorZ, 2.5
            return 2.5
        end
    end

    local maxFoundToxicity = 0.0
    local floorScale = 5.0 -- 1階層につき水平5タイル分の減衰

    for _, hotspot in ipairs(NE.HotspotRegistry) do
        local radius = (survivalDays - 1) * (NE.ContaminationRate * expansionSpeed) * hotspot.strength + 15.0

        local dx = floorX - hotspot.x
        local dy = floorY - hotspot.y
        local dz = (floorZ - hotspot.z) * floorScale
        
        -- 3D距離計算
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist < radius then
            local rawTox = (1.0 - (dist / radius)) * hotspot.strength
            
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
