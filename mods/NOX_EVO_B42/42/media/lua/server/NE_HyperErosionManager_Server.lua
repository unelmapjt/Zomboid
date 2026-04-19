-- --------------------------------------------------------------------------
-- NE_HyperErosionManager_Server.lua
-- Role: ロードタイルへ「5年後の廃墟」多層劣化オーバーレイ（サーバー専用）
-- 判定: SandboxVars.ErosionDays >= 1825（isNoxErosionWorld。gameMode は見ない）
-- オブジェクト: 10YL と同型 IsoObject.new(getCell(), square, spriteName)
-- スプライト: TYL_TREEGENERATOR_SERVER.lua 系リファレンス（名称は変更禁止）
-- --------------------------------------------------------------------------

local NE_Erosion = {}

-- B42: ZombRand(n) は 0 .. n-1。配列は 1 + ZombRand(#t) で参照する。

local VINE_SPRITES = {
    "f_wallvines_1_0", "f_wallvines_1_1", "f_wallvines_1_2", "f_wallvines_1_3",
    "f_wallvines_1_4", "f_wallvines_1_5", "f_wallvines_1_6", "f_wallvines_1_7",
    "f_wallvines_1_8", "f_wallvines_1_9", "f_wallvines_1_10", "f_wallvines_1_11",
    "f_wallvines_1_12", "f_wallvines_1_13", "f_wallvines_1_14", "f_wallvines_1_15",
}
local GRASS_SPRITES = {
    "e_newgrass_1_34", "e_newgrass_1_33", "e_newgrass_1_24", "e_newgrass_1_27",
    "e_newgrass_1_28", "e_newgrass_1_29", "e_newgrass_1_53", "e_newgrass_1_52", "e_newgrass_1_51",
}
local LEAVES_SPRITES = {
    "d_floorleaves_1_10", "d_floorleaves_1_5", "d_floorleaves_1_8", "d_floorleaves_1_7",
    "d_floorleaves_1_2", "d_floorleaves_1_9", "d_floorleaves_1_4", "d_floorleaves_1_11",
}
local ROOF_SPRITES = {
    "roofs_burnt_01_22", "roofs_03_22", "roofs_03_23", "roofs_04_22", "roofs_04_23", "carpentry_02_58",
}
-- 屋根（上階床）スプライト名の明示リスト — getName() 完全一致で判定
local ROOF_TOP = {
    ["roofs_01_22"] = true, ["roofs_01_23"] = true, ["roofs_02_22"] = true, ["roofs_02_23"] = true,
    ["roofs_01_90"] = true, ["roofs_01_91"] = true, ["roofs_01_92"] = true, ["roofs_01_93"] = true,
    ["roofs_02_90"] = true, ["roofs_02_91"] = true, ["roofs_02_92"] = true, ["roofs_02_93"] = true,
    ["roofs_05_22"] = true, ["roofs_05_23"] = true, ["roofs_06_22"] = true, ["roofs_06_23"] = true,
}
local TRASH_SPRITES = {
    "trash_01_0", "trash_01_1", "trash_01_2", "trash_01_3", "trash_01_4",
}

local guardTraceEmitted = false

local function isNoxErosionWorld()
    return SandboxVars
        and type(SandboxVars.ErosionDays) == "number"
        and SandboxVars.ErosionDays >= 1825
end

local function addOverlayIsoObject(square, spriteName)
    local cell = getCell()
    if not cell then
        return
    end
    local obj = IsoObject.new(cell, square, spriteName)
    if obj then
        square:AddTileObject(obj)
    end
end

function NE_Erosion.Apply(square)
    local pass = isNoxErosionWorld()
    if not guardTraceEmitted and Z_TRACER and Z_TRACER.EmitTrace then
        guardTraceEmitted = true
        local core = getCore()
        local gm = core and core:getGameMode() or "nil"
        local ed = SandboxVars and SandboxVars.ErosionDays
        Z_TRACER.EmitTrace("NE_EROSION", "HyperErosionManager_Server",
            "GuardOnce|pass=" .. tostring(pass) .. "|gameMode=" .. tostring(gm) .. "|ErosionDays=" .. tostring(ed), "INFO")
    end
    if not pass then
        return
    end

    local modData = square:getModData()
    if modData and modData.NE_ErosionDone then
        return
    end

    local rand = ZombRand(100)
    local floor = square:getFloor()
    local floorName = ""
    if floor and floor:getSprite() and floor:getSprite():getName() then
        floorName = floor:getSprite():getName()
    end

    -- [1] 壁 → 蔦 (60%)
    if square:getWall(false) and rand < 60 then
        local s = VINE_SPRITES[1 + ZombRand(#VINE_SPRITES)]
        addOverlayIsoObject(square, s)
    end
    -- [2] 舗装・アスファルト → 草の浸食 (40%)
    if (string.find(floorName, "street") or string.find(floorName, "pavement")) and rand < 40 then
        local s = GRASS_SPRITES[1 + ZombRand(#GRASS_SPRITES)]
        addOverlayIsoObject(square, s)
    end
    -- [3] 屋内床（タイル・木材） → 落ち葉 (30%)
    if (string.find(floorName, "tiles") or string.find(floorName, "wood") or string.find(floorName, "carpet")) and rand < 30 then
        local s = LEAVES_SPRITES[1 + ZombRand(#LEAVES_SPRITES)]
        addOverlayIsoObject(square, s)
    end
    -- [4] 屋根 → 崩壊 (20%) — ROOF_TOP 明示リストで上階床スプライトと判定（getRoof 不使用）
    if ROOF_TOP[floorName] and rand < 20 then
        local s = ROOF_SPRITES[1 + ZombRand(#ROOF_SPRITES)]
        addOverlayIsoObject(square, s)
    end
    -- [5] 道路・駐車場 → ゴミ散乱 (15%)
    if (string.find(floorName, "street") or string.find(floorName, "asphalt")) and ZombRand(100) < 15 then
        local s = TRASH_SPRITES[1 + ZombRand(#TRASH_SPRITES)]
        addOverlayIsoObject(square, s)
    end

    modData = square:getModData()
    if modData then
        modData.NE_ErosionDone = true
    end
end

Events.LoadGridsquare.Add(NE_Erosion.Apply)

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "HyperErosionManager_Server", "Register:LoadGridsquare|Server|MultiLayerErosion", "INFO")
end
