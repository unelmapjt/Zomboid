-- NE_MutationClimateVisual.lua — ImprovedFog（OnClimateTick）+ タイル着色（計算 8 ティック／描画毎ティック）
-- 煙: IsoFireManager.StartSmoke は一時無効（地面着色優先）。sq:addVisualEffect は未使用。

print(">>> [NE] CLIMATE FILTER SYSTEM ACTIVE")

NE = NE or {}

local NE_ZONE_MULT_MAX = 2.5
local NE_EPS = 1e-5

--- プレイヤー中心の正方形半辺（タイル）
local NE_TILE_RADIUS = 15
--- タイル走査の間隔（ティック）。5〜10 の範囲の target として 8 を使用
local NE_TILE_VIS_INTERVAL = 8

local NE_BASE_GREEN_R = 0.1
local NE_BASE_GREEN_G = 0.8
local NE_BASE_GREEN_B = 0.1

local _neTileTickAcc = 0
--- [ "x,y,z" ] = { r, g, b } — 汚染タイルの座標と色（スキャンで更新、描画で毎ティック適用）
local _neActiveContaminatedTiles = {}

local function NE_ResetFloorHighlight(sq)
    local floor = sq:getFloor()
    if not floor then
        return
    end
    floor:setHighlighted(false)
    floor:setHighlightColor(ColorInfo.new(1.0, 1.0, 1.0, 1.0))
end

local function NE_ClearAllTrackedFloorHighlights()
    local cell = getCell()
    if not cell then
        _neActiveContaminatedTiles = {}
        return
    end
    for key, _ in pairs(_neActiveContaminatedTiles) do
        local ix, iy, iz = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
        ix, iy, iz = tonumber(ix), tonumber(iy), tonumber(iz)
        if ix then
            local sq = cell:getGridSquare(ix, iy, iz)
            if sq then
                NE_ResetFloorHighlight(sq)
            end
        end
    end
    _neActiveContaminatedTiles = {}
end

--- 登録済みタイルへ毎ティックハイライトを再適用（バニラの上書きによる点滅抑止）
local function NE_DrawTileHighlights()
    if NE.Switches and NE.Switches.EnableMutation == false then
        if next(_neActiveContaminatedTiles) ~= nil then
            NE_ClearAllTrackedFloorHighlights()
        end
        return
    end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() then
        NE_ClearAllTrackedFloorHighlights()
        return
    end

    local cell = getCell()
    if not cell then
        return
    end

    for key, c in pairs(_neActiveContaminatedTiles) do
        local ix, iy, iz = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
        ix, iy, iz = tonumber(ix), tonumber(iy), tonumber(iz)
        if ix and c and c.r and c.g and c.b then
            local sq = cell:getGridSquare(ix, iy, iz)
            if sq then
                local floor = sq:getFloor()
                if floor then
                    floor:setHighlightColor(ColorInfo.new(c.r, c.g, c.b, 1.0))
                    floor:setHighlighted(true)
                end
            end
        end
    end
end

--- 半径 NE_TILE_RADIUS を走査し、汚染度と色のみ _neActiveContaminatedTiles に保存（8 ティックごと）
local function NE_UpdateTileVisuals()
    if NE.Switches and NE.Switches.EnableMutation == false then
        NE_ClearAllTrackedFloorHighlights()
        return
    end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() then
        NE_ClearAllTrackedFloorHighlights()
        return
    end

    if not NE.GetZoneMultiplier then
        return
    end

    local cell = getCell()
    if not cell then
        return
    end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    local nextActive = {}

    for dx = -NE_TILE_RADIUS, NE_TILE_RADIUS do
        for dy = -NE_TILE_RADIUS, NE_TILE_RADIUS do
            local x, y, z = px + dx, py + dy, pz
            local sq = cell:getGridSquare(x, y, z)
            if sq then
                local key = x .. "," .. y .. "," .. z
                local tox = NE.GetZoneMultiplier(x, y, z)

                if tox > NE_EPS then
                    local intensity = math.min(1.0, tox / NE_ZONE_MULT_MAX)
                    local r = (1.0 - intensity) * 1.0 + intensity * NE_BASE_GREEN_R
                    local g = (1.0 - intensity) * 1.0 + intensity * NE_BASE_GREEN_G
                    local b = (1.0 - intensity) * 1.0 + intensity * NE_BASE_GREEN_B
                    nextActive[key] = { r = r, g = g, b = b }
                else
                    if _neActiveContaminatedTiles[key] then
                        NE_ResetFloorHighlight(sq)
                    end
                end
            end
        end
    end

    for key, _ in pairs(_neActiveContaminatedTiles) do
        if not nextActive[key] then
            local ix, iy, iz = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
            ix, iy, iz = tonumber(ix), tonumber(iy), tonumber(iz)
            if ix then
                local sq = cell:getGridSquare(ix, iy, iz)
                if sq then
                    NE_ResetFloorHighlight(sq)
                end
            end
        end
    end

    _neActiveContaminatedTiles = nextActive
end

local function NE_OnTickTileVisuals()
    _neTileTickAcc = _neTileTickAcc + 1
    if _neTileTickAcc >= NE_TILE_VIS_INTERVAL then
        _neTileTickAcc = 0
        NE_UpdateTileVisuals()
    end
    NE_DrawTileHighlights()
end

local function NE_ApplyMutationFilter()
    if NE.Switches and NE.Switches.EnableMutation == false then
        return
    end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() then
        return
    end

    if not player.getModData then
        return
    end
    local md = player:getModData()
    if not md then
        return
    end

    local zoneMult = tonumber(md.NE_RawZoneMult) or 0.0
    local T_zone = math.min(1.0, math.max(0.0, zoneMult / NE_ZONE_MULT_MAX))

    if not ImprovedFog then
        return
    end

    if T_zone <= NE_EPS then
        ImprovedFog.setEnableEditing(false)
        return
    end

    local cm = getClimateManager()
    if not cm then
        ImprovedFog.setEnableEditing(false)
        return
    end

    ImprovedFog.setEnableEditing(true)
    ImprovedFog.setBaseAlpha(T_zone * 0.75)
    ImprovedFog.setAlphaCircleRad(10 - T_zone * 6)
    ImprovedFog.setAlphaCircleAlpha(0.25)

    local dls = cm:getDayLightStrength()
    local r = dls * (1.0 - T_zone * 0.5)
    local g = dls * (1.0 + T_zone * 0.7)
    local b = dls * (1.0 - T_zone * 0.3)
    ImprovedFog.setColorR(r)
    ImprovedFog.setColorG(g)
    ImprovedFog.setColorB(b)
end

if Events.OnClimateTick and Events.OnClimateTick.Add then
    Events.OnClimateTick.Add(NE_ApplyMutationFilter)
end

-- 描画（毎ティック）＋スキャン（NE_TILE_VIS_INTERVAL ごと）を同一 OnTick で処理
if Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(NE_OnTickTileVisuals)
end
