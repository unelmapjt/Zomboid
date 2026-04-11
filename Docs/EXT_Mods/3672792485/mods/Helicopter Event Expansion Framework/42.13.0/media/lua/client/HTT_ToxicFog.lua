require "HTT_Main"

HTT = HTT or {}

if HTT._clientToxicFogLoaded then
    return
end
HTT._clientToxicFogLoaded = true

local CLIMATE_FLOAT_FOG_INTENSITY = 5
local SMOKE_CLIMATE_FLOAT_KEYS = {
    "NIGHT_STRENGTH",
    "CLOUD_INTENSITY",
    "GLOBAL_LIGHT_INTENSITY",
    "AMBIENT",
    "DAYLIGHT_STRENGTH",
    "DESATURATION",
    "VIEW_DISTANCE",
}
local TOXIC_CLIMATE_FLOAT_KEYS = {
    "NIGHT_STRENGTH",
    "CLOUD_INTENSITY",
    "GLOBAL_LIGHT_INTENSITY",
    "AMBIENT",
    "DAYLIGHT_STRENGTH",
    "DESATURATION",
    "VIEW_DISTANCE",
}
local TOXIC_CLIMATE_COLOR_KEYS = {
    "COLOR_NEW_FOG",
}
local SMOKE_CLIMATE_COLOR_KEYS = {
    "COLOR_NEW_FOG",
}
local TOXIC_FOG_COLOR = {
    r = 0.36,
    g = 0.68,
    b = 0.34,
    a = 1.00,
}
local SMOKE_FOG_COLOR = {
    r = 0.86,
    g = 0.86,
    b = 0.89,
    a = 1.00,
}
local smokeClimateApplied = false
local toxicClimateApplied = false
local toxicImprovedFogEditing = false
local climateFloatIdCache = {}
local climateColorIdCache = {}
local setFogOverride
local logFogControllerSnapshot
local lastFogDebugMode = "__init__"
local lastFogDebugEventId = "__init__"
local lastFogDebugPhase = "__init__"
local lastFogDebugActive = nil
local missingClimateFloatKeysLogged = {}
local missingClimateColorKeysLogged = {}
local fogControllerMissingLogged = false
local EVENT_FOG_MIGRATION_KEY = "HTT_EventFogMigration"
local EVENT_FOG_MIGRATION_VERSION = "2026-03-03-smoke-climate-cleanup-v1"
local legacyFogMigrationPending = true

local function clamp01(value)
    local n = HTT.toNumber(value, 0)
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function toUpperSafe(value)
    if type(value) ~= "string" then
        return ""
    end
    if string and string.upper then
        return string.upper(value)
    end
    return value
end

local function normalizeClimateKey(value)
    local upper = toUpperSafe(value)
    if upper == "" then
        return ""
    end
    if string and string.gsub then
        upper = string.gsub(upper, "[^A-Z0-9]", "")
    end
    return upper
end

local function isClimateNameAliasMatch(expected, actual)
    if expected == actual then
        return true
    end
    if expected == "DAYLIGHTSTRENGTH" and actual == "DAYLIGHT" then
        return true
    end
    if expected == "FOGINTENSITY" and actual == "FOG" then
        return true
    end
    if expected == "COLORNEWFOG" then
        return actual == "NEWFOG" or actual == "FOGCOLOR"
    end
    return false
end

local function climateParamNameMatches(param, normalizedExpected)
    if not param or not param.getName or normalizedExpected == "" then
        return false
    end
    local okName, rawName = pcall(function()
        return param:getName()
    end)
    if not okName then
        return false
    end
    local normalizedRaw = normalizeClimateKey(rawName)
    return isClimateNameAliasMatch(normalizedExpected, normalizedRaw)
end

local function registerEvent(eventName, callback)
    if not Events then
        HTT.log("Events table is not available while registering " .. tostring(eventName))
        return false
    end

    local evt = Events[eventName]
    if evt and evt.Add then
        evt.Add(callback)
        return true
    end

    HTT.log("Event not available: " .. tostring(eventName))
    return false
end

local function getPlayerModDataSafe()
    local player = getPlayer and getPlayer() or nil
    if not player or not player.getModData then
        return nil
    end

    local ok, modData = pcall(function()
        return player:getModData()
    end)
    if not ok then
        return nil
    end
    return modData
end

local function resolveClimateManager()
    local cm = nil
    if getClimateManager then
        cm = getClimateManager()
    end

    if not cm and getWorld then
        local world = getWorld()
        if world and world.getClimateManager then
            cm = world:getClimateManager()
        end
    end

    if not cm then
        return nil
    end

    return cm
end

local function resolveFogController()
    local cm = resolveClimateManager()
    if not cm or not cm.getClimateFloat then
        return nil
    end

    local targetName = "FOGINTENSITY"
    local fogFloat = nil

    if ClimateManager and ClimateManager.FLOAT_FOG_INTENSITY ~= nil then
        local okConst, value = pcall(function()
            return cm:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY)
        end)
        if okConst and climateParamNameMatches(value, targetName) then
            fogFloat = value
        end
    end

    if not fogFloat and cm.getFloatMax then
        local okMax, total = pcall(function()
            return cm:getFloatMax()
        end)
        if okMax and total then
            for i = 0, total - 1 do
                local okFloat, floatParam = pcall(function()
                    return cm:getClimateFloat(i)
                end)
                if okFloat and climateParamNameMatches(floatParam, targetName) then
                    fogFloat = floatParam
                    break
                end
            end
        end
    end

    if not fogFloat then
        local okLegacy, legacy = pcall(function()
            return cm:getClimateFloat(CLIMATE_FLOAT_FOG_INTENSITY)
        end)
        if okLegacy and climateParamNameMatches(legacy, targetName) then
            fogFloat = legacy
        end
    end

    return fogFloat
end

local function resolveClimateFloatId(key)
    local cacheKey = normalizeClimateKey(key)
    if cacheKey == "" then
        return nil
    end

    local cached = climateFloatIdCache[cacheKey]
    if cached ~= nil then
        return cached == false and nil or cached
    end

    if ClimateManager then
        if cacheKey == "NIGHTSTRENGTH" then
            cached = ClimateManager.FLOAT_NIGHT_STRENGTH
        elseif cacheKey == "FOGINTENSITY" then
            cached = ClimateManager.FLOAT_FOG_INTENSITY
        elseif cacheKey == "CLOUDINTENSITY" then
            cached = ClimateManager.FLOAT_CLOUD_INTENSITY
        elseif cacheKey == "GLOBALLIGHTINTENSITY" then
            cached = ClimateManager.FLOAT_GLOBAL_LIGHT_INTENSITY
        elseif cacheKey == "AMBIENT" then
            cached = ClimateManager.FLOAT_AMBIENT
        elseif cacheKey == "DAYLIGHTSTRENGTH" or cacheKey == "DAYLIGHT" then
            cached = ClimateManager.FLOAT_DAYLIGHT_STRENGTH or ClimateManager.FLOAT_DAYLIGHT
        elseif cacheKey == "DESATURATION" then
            cached = ClimateManager.FLOAT_DESATURATION
        elseif cacheKey == "VIEWDISTANCE" then
            cached = ClimateManager.FLOAT_VIEW_DISTANCE
        end
    end

    if cached ~= nil then
        climateFloatIdCache[cacheKey] = cached
        return cached
    end

    local cm = resolveClimateManager()
    if cm and cm.getFloatMax and cm.getClimateFloat then
        local okMax, total = pcall(function()
            return cm:getFloatMax()
        end)
        if okMax and total then
            local targetName = normalizeClimateKey(cacheKey)
            for i = 0, total - 1 do
                local okFloat, floatParam = pcall(function()
                    return cm:getClimateFloat(i)
                end)
                if okFloat and climateParamNameMatches(floatParam, targetName) then
                    climateFloatIdCache[cacheKey] = i
                    return i
                end
            end
        end
    end

    climateFloatIdCache[cacheKey] = false
    return nil
end

local function resolveClimateFloatById(id)
    local cm = resolveClimateManager()
    if not cm or not cm.getClimateFloat or id == nil then
        return nil
    end

    local ok, value = pcall(function()
        return cm:getClimateFloat(id)
    end)
    if not ok then
        return nil
    end
    return value
end

local function resolveClimateColorId(key)
    local cacheKey = normalizeClimateKey(key)
    if cacheKey == "" then
        return nil
    end

    local cached = climateColorIdCache[cacheKey]
    if cached ~= nil then
        return cached == false and nil or cached
    end

    if ClimateManager then
        if cacheKey == "COLORNEWFOG" then
            cached = ClimateManager.COLOR_NEW_FOG
        elseif cacheKey == "GLOBALLIGHT" then
            cached = ClimateManager.COLOR_GLOBAL_LIGHT
        end
    end

    if cached ~= nil then
        climateColorIdCache[cacheKey] = cached
        return cached
    end

    local cm = resolveClimateManager()
    if cm and cm.getColorMax and cm.getClimateColor then
        local okMax, total = pcall(function()
            return cm:getColorMax()
        end)
        if okMax and total then
            local targetName = normalizeClimateKey(cacheKey)
            for i = 0, total - 1 do
                local okColor, colorParam = pcall(function()
                    return cm:getClimateColor(i)
                end)
                if okColor and climateParamNameMatches(colorParam, targetName) then
                    climateColorIdCache[cacheKey] = i
                    return i
                end
            end
        end
    end

    climateColorIdCache[cacheKey] = false
    return nil
end

local function resolveClimateColorById(id)
    local cm = resolveClimateManager()
    if not cm or not cm.getClimateColor or id == nil then
        return nil
    end

    local ok, value = pcall(function()
        return cm:getClimateColor(id)
    end)
    if not ok then
        return nil
    end
    return value
end

local function setModdedClimateFloat(key, value)
    local id = resolveClimateFloatId(key)
    local climateFloat = resolveClimateFloatById(id)
    if not climateFloat then
        local cacheKey = normalizeClimateKey(key)
        if cacheKey ~= "" and not missingClimateFloatKeysLogged[cacheKey] and HTT.log then
            missingClimateFloatKeysLogged[cacheKey] = true
            HTT.log("Climate float not found for key=" .. tostring(key))
        end
        return false
    end

    local n = HTT.toNumber(value, 0)
    local usedOverride = false
    local usedModded = false
    local usedAdmin = false
    if climateFloat.setEnableOverride and climateFloat.setOverride then
        local okOverride = pcall(function()
            climateFloat:setEnableOverride(true)
            climateFloat:setOverride(n, 1.0)
        end)
        if okOverride then
            usedOverride = true
        end
    end
    if usedOverride then
        if climateFloat.setEnableModded then
            pcall(function()
                climateFloat:setEnableModded(false)
            end)
        end
        if climateFloat.setEnableAdmin then
            pcall(function()
                climateFloat:setEnableAdmin(false)
            end)
        end
        return true
    end

    if climateFloat.setEnableModded then
        pcall(function()
            climateFloat:setEnableModded(true)
        end)
    end
    if climateFloat.setModdedInterpolate then
        pcall(function()
            climateFloat:setModdedInterpolate(1.0)
        end)
    end
    if climateFloat.setModdedValue then
        pcall(function()
            climateFloat:setModdedValue(n)
        end)
        usedModded = true
    elseif climateFloat.setAdminValue then
        if climateFloat.setEnableAdmin then
            pcall(function()
                climateFloat:setEnableAdmin(true)
            end)
        end
        pcall(function()
            climateFloat:setAdminValue(n)
        end)
        usedAdmin = true
    end
    if climateFloat.setEnableAdmin and not usedAdmin then
        pcall(function()
            climateFloat:setEnableAdmin(false)
        end)
    end
    if climateFloat.setEnableOverride and usedModded then
        pcall(function()
            climateFloat:setEnableOverride(false)
        end)
    end

    return true
end

local function clearModdedClimateFloat(key)
    local id = resolveClimateFloatId(key)
    local climateFloat = resolveClimateFloatById(id)
    if not climateFloat then
        return
    end

    if climateFloat.setEnableModded then
        pcall(function()
            climateFloat:setEnableModded(false)
        end)
    end
    if climateFloat.setEnableAdmin then
        pcall(function()
            climateFloat:setEnableAdmin(false)
        end)
    end
    if climateFloat.setEnableOverride then
        pcall(function()
            climateFloat:setEnableOverride(false)
        end)
    end
    if climateFloat.setOverrideValue then
        pcall(function()
            climateFloat:setOverrideValue(false)
        end)
    end
end

local function setModdedClimateColor(key, r, g, b, a)
    local id = resolveClimateColorId(key)
    local climateColor = resolveClimateColorById(id)
    if not climateColor then
        local cacheKey = normalizeClimateKey(key)
        if cacheKey ~= "" and not missingClimateColorKeysLogged[cacheKey] and HTT.log then
            missingClimateColorKeysLogged[cacheKey] = true
            HTT.log("Climate color not found for key=" .. tostring(key))
        end
        return false
    end

    local colorInfo = nil
    if ClimateColorInfo and ClimateColorInfo.new then
        local okInfo, value = pcall(function()
            return ClimateColorInfo.new()
        end)
        if okInfo and value then
            colorInfo = value
        end
    elseif zombie and zombie.iso and zombie.iso.weather and zombie.iso.weather.ClimateColorInfo then
        local okInfo, value = pcall(function()
            return zombie.iso.weather.ClimateColorInfo.new()
        end)
        if okInfo and value then
            colorInfo = value
        end
    end
    if not colorInfo then
        return false
    end

    local rr = clamp01(r)
    local gg = clamp01(g)
    local bb = clamp01(b)
    local aa = clamp01(a)
    if colorInfo.setInterior then
        pcall(function()
            colorInfo:setInterior(rr, gg, bb, aa)
        end)
    end
    if colorInfo.setExterior then
        pcall(function()
            colorInfo:setExterior(rr, gg, bb, aa)
        end)
    end

    if climateColor.setEnableOverride and climateColor.setOverride then
        local okOverride = pcall(function()
            climateColor:setEnableOverride(true)
            climateColor:setOverride(colorInfo, 1.0)
        end)
        if okOverride then
            if climateColor.setEnableModded then
                pcall(function()
                    climateColor:setEnableModded(false)
                end)
            end
            if climateColor.setEnableAdmin then
                pcall(function()
                    climateColor:setEnableAdmin(false)
                end)
            end
            return true
        end
    end

    if climateColor.setEnableModded then
        pcall(function()
            climateColor:setEnableModded(true)
        end)
    end
    if climateColor.setModdedInterpolate then
        pcall(function()
            climateColor:setModdedInterpolate(1.0)
        end)
    end
    if climateColor.setModdedValue then
        pcall(function()
            climateColor:setModdedValue(colorInfo)
        end)
    end
    if climateColor.setEnableAdmin then
        pcall(function()
            climateColor:setEnableAdmin(false)
        end)
    end
    if climateColor.setEnableOverride then
        pcall(function()
            climateColor:setEnableOverride(false)
        end)
    end

    return true
end

local function clearModdedClimateColor(key)
    local id = resolveClimateColorId(key)
    local climateColor = resolveClimateColorById(id)
    if not climateColor then
        return
    end

    if climateColor.setEnableModded then
        pcall(function()
            climateColor:setEnableModded(false)
        end)
    end
    if climateColor.setEnableAdmin then
        pcall(function()
            climateColor:setEnableAdmin(false)
        end)
    end
    if climateColor.setEnableOverride then
        pcall(function()
            climateColor:setEnableOverride(false)
        end)
    end
end

local function applyImprovedFogColor(r, g, b)
    toxicImprovedFogEditing = false
    return false
end

local function clearImprovedFogColor()
    toxicImprovedFogEditing = false
end

local function applySmokeClimateStack()
    if smokeClimateApplied then
        setModdedClimateColor(
            "COLOR_NEW_FOG",
            SMOKE_FOG_COLOR.r,
            SMOKE_FOG_COLOR.g,
            SMOKE_FOG_COLOR.b,
            SMOKE_FOG_COLOR.a
        )
        applyImprovedFogColor(
            SMOKE_FOG_COLOR.r,
            SMOKE_FOG_COLOR.g,
            SMOKE_FOG_COLOR.b
        )
        return
    end

    setModdedClimateFloat("NIGHT_STRENGTH", 1.0)
    setModdedClimateFloat("CLOUD_INTENSITY", 1.0)
    setModdedClimateFloat("GLOBAL_LIGHT_INTENSITY", 0.04)
    setModdedClimateFloat("AMBIENT", 0.03)
    setModdedClimateFloat("DAYLIGHT_STRENGTH", 0.04)
    setModdedClimateFloat("DESATURATION", 1.0)
    setModdedClimateFloat("VIEW_DISTANCE", 2.5)
    setModdedClimateColor(
        "COLOR_NEW_FOG",
        SMOKE_FOG_COLOR.r,
        SMOKE_FOG_COLOR.g,
        SMOKE_FOG_COLOR.b,
        SMOKE_FOG_COLOR.a
    )
    applyImprovedFogColor(
        SMOKE_FOG_COLOR.r,
        SMOKE_FOG_COLOR.g,
        SMOKE_FOG_COLOR.b
    )
    smokeClimateApplied = true
end

local function clearSmokeClimateStack(forceClear)
    local mustClear = forceClear == true
    if not mustClear and not smokeClimateApplied then
        return
    end

    for i = 1, #SMOKE_CLIMATE_FLOAT_KEYS do
        clearModdedClimateFloat(SMOKE_CLIMATE_FLOAT_KEYS[i])
    end
    for i = 1, #SMOKE_CLIMATE_COLOR_KEYS do
        clearModdedClimateColor(SMOKE_CLIMATE_COLOR_KEYS[i])
    end
    clearImprovedFogColor()
    smokeClimateApplied = false
end

local function applyToxicClimateStack()
    if toxicClimateApplied then
        setModdedClimateColor(
            "COLOR_NEW_FOG",
            TOXIC_FOG_COLOR.r,
            TOXIC_FOG_COLOR.g,
            TOXIC_FOG_COLOR.b,
            TOXIC_FOG_COLOR.a
        )
        applyImprovedFogColor(
            TOXIC_FOG_COLOR.r,
            TOXIC_FOG_COLOR.g,
            TOXIC_FOG_COLOR.b
        )
        return
    end

    setModdedClimateFloat("CLOUD_INTENSITY", 0.95)
    setModdedClimateFloat("DESATURATION", 0.55)
    setModdedClimateFloat("VIEW_DISTANCE", 2.8)

    setModdedClimateColor(
        "COLOR_NEW_FOG",
        TOXIC_FOG_COLOR.r,
        TOXIC_FOG_COLOR.g,
        TOXIC_FOG_COLOR.b,
        TOXIC_FOG_COLOR.a
    )
    applyImprovedFogColor(
        TOXIC_FOG_COLOR.r,
        TOXIC_FOG_COLOR.g,
        TOXIC_FOG_COLOR.b
    )
    toxicClimateApplied = true
end

local function clearToxicClimateStack(forceClear)
    local mustClear = forceClear == true
    if not mustClear and not toxicClimateApplied then
        clearImprovedFogColor()
        return
    end

    for i = 1, #TOXIC_CLIMATE_FLOAT_KEYS do
        clearModdedClimateFloat(TOXIC_CLIMATE_FLOAT_KEYS[i])
    end
    for i = 1, #TOXIC_CLIMATE_COLOR_KEYS do
        clearModdedClimateColor(TOXIC_CLIMATE_COLOR_KEYS[i])
    end
    clearImprovedFogColor()
    toxicClimateApplied = false
end

local function forceClearEventFog(reason, forceLegacyClear)
    clearSmokeClimateStack(true)
    clearToxicClimateStack(true)
    setFogOverride(0)
    if logFogControllerSnapshot then
        logFogControllerSnapshot("post-clear-" .. tostring(reason or "none"))
    end
    if reason then
        HTT.log("Event fog cleared: " .. tostring(reason))
    end
end

HTT.ClearSmokeCurtainFog = forceClearEventFog
HTT.ClearEventFog = forceClearEventFog

local function runLegacyFogMigrationIfNeeded(climateMode)
    if not legacyFogMigrationPending then
        return
    end

    local modData = getPlayerModDataSafe()
    if modData and tostring(modData[EVENT_FOG_MIGRATION_KEY] or "") == EVENT_FOG_MIGRATION_VERSION then
        legacyFogMigrationPending = false
        return
    end

    if climateMode ~= "none" then
        return
    end

    forceClearEventFog("legacy-smoke-fog-migration", true)
    if modData then
        modData[EVENT_FOG_MIGRATION_KEY] = EVENT_FOG_MIGRATION_VERSION
    end
    legacyFogMigrationPending = false
end

local function disableFogControl(fogF)
    if not fogF then
        return
    end

    if fogF.setEnableAdmin then
        pcall(function()
            fogF:setEnableAdmin(false)
        end)
    end
    if fogF.setEnableOverride then
        pcall(function()
            fogF:setEnableOverride(false)
        end)
    end
    if fogF.setEnableModded then
        pcall(function()
            fogF:setEnableModded(false)
        end)
    end
end

logFogControllerSnapshot = function(tag)
    if not HTT.log then
        return
    end

    local fogF = resolveFogController()
    if not fogF then
        HTT.log("Fog controller snapshot [" .. tostring(tag) .. "]: unavailable")
        return
    end

    local internalValue = fogF.getInternalValue and fogF:getInternalValue() or -1
    local finalValue = fogF.getFinalValue and fogF:getFinalValue() or -1
    local overrideValue = fogF.getOverride and fogF:getOverride() or -1
    local moddedValue = fogF.getModdedValue and fogF:getModdedValue() or -1
    local adminValue = fogF.getAdminValue and fogF:getAdminValue() or -1
    local overrideEnabled = fogF.isEnableOverride and fogF:isEnableOverride() or false
    local adminEnabled = fogF.isEnableAdmin and fogF:isEnableAdmin() or false

    HTT.log(string.format(
        "Fog controller snapshot [%s]: internal=%.3f final=%.3f override=%.3f modded=%.3f admin=%.3f overrideOn=%s adminOn=%s",
        tostring(tag),
        HTT.toNumber(internalValue, -1),
        HTT.toNumber(finalValue, -1),
        HTT.toNumber(overrideValue, -1),
        HTT.toNumber(moddedValue, -1),
        HTT.toNumber(adminValue, -1),
        tostring(overrideEnabled),
        tostring(adminEnabled)
    ))
end

setFogOverride = function(value)
    local cm = resolveClimateManager()
    local fogF = resolveFogController()

    local intensity = clamp01(value)
    if intensity <= 0 then
        if fogF then
            if fogF.setEnableAdmin then
                pcall(function()
                    fogF:setEnableAdmin(false)
                end)
            end
            if fogF.setEnableModded and fogF.setModdedValue then
                pcall(function()
                    fogF:setEnableModded(true)
                    if fogF.setModdedInterpolate then
                        fogF:setModdedInterpolate(1.0)
                    end
                    fogF:setModdedValue(0.0)
                end)
            end
            if fogF.setEnableOverride then
                pcall(function()
                    fogF:setEnableOverride(true)
                end)
            end
            if fogF.setOverride then
                pcall(function()
                    fogF:setOverride(0.0, 1.0)
                end)
            end
            if fogF.setFinalValue then
                pcall(function()
                    fogF:setFinalValue(0.0)
                end)
            end
        elseif cm and cm.setFogIntensity then
            pcall(function()
                cm:setFogIntensity(0.0)
            end)
        end
        return
    end

    if not fogF then
        if not fogControllerMissingLogged and HTT.log then
            fogControllerMissingLogged = true
            HTT.log("Fog controller unavailable; using climate-float fallback.")
        end
        if not setModdedClimateFloat("FOG_INTENSITY", intensity) and cm and cm.setFogIntensity then
            pcall(function()
                cm:setFogIntensity(intensity)
            end)
        end
        return
    end

    if fogF.setEnableOverride and fogF.setOverride then
        pcall(function()
            fogF:setEnableOverride(true)
        end)

        local smooth = 1.0
        local ok = pcall(function()
            fogF:setOverride(intensity, smooth)
        end)
        if not ok then
            pcall(function()
                fogF:setOverride(intensity)
            end)
        end
        if fogF.setEnableAdmin then
            pcall(function()
                fogF:setEnableAdmin(false)
            end)
        end
        if fogF.setEnableModded then
            pcall(function()
                fogF:setEnableModded(false)
            end)
        end
        return
    end

    if fogF.setEnableModded and fogF.setModdedValue and fogF.setModdedInterpolate then
        pcall(function()
            fogF:setEnableModded(true)
            fogF:setModdedInterpolate(1.0)
            fogF:setModdedValue(intensity)
        end)
        if fogF.setEnableAdmin then
            pcall(function()
                fogF:setEnableAdmin(false)
            end)
        end
        if fogF.setEnableOverride then
            pcall(function()
                fogF:setEnableOverride(false)
            end)
        end
        return
    end

    if fogF.setEnableAdmin and fogF.setAdminValue then
        pcall(function()
            fogF:setEnableAdmin(true)
        end)
        pcall(function()
            fogF:setAdminValue(intensity)
        end)
    end
end

local function getEventFogTarget()
    local state = HTT.serverEvent or {}
    local eventId = tostring(state.eventId or "")
    local localRelevant = HTT.IsLocalPlayerRelevantToEventState
        and HTT.IsLocalPlayerRelevantToEventState(state)
        or false

    if eventId ~= "smoke_curtain_event" and HTT.Config.EnableToxicFog == false then
        return 0, "none"
    end

    if eventId == "toxic" then
        if not localRelevant then
            return 0, "none"
        end

        local activeFog = clamp01(HTT.toNumber(HTT.Config.ToxicFogIntensityActive, 1.00))
        local approachFog = clamp01(HTT.toNumber(HTT.Config.ToxicFogIntensityApproach, 0.88))
        local phase = tostring(state.toxicPhase or "")

        if state.active == true then
            if phase == "active" or phase == "" then
                return activeFog, "toxic"
            end
            if phase == "approach" then
                return approachFog, "toxic"
            end
        end

        local fadeMinutes = HTT.toNumber(state.fadeMinutes, 0)
        if fadeMinutes > 0 then
            local totalFade = HTT.toNumber(HTT.Config.ToxicFadeMinutes, 10)
            if totalFade <= 0 then
                totalFade = 10
            end
            return activeFog * clamp01(fadeMinutes / totalFade), "toxic"
        end

        return 0, "none"
    end

    if eventId == "smoke_curtain_event" and state.active == true then
        if not localRelevant then
            return 0, "none"
        end

        local smokeActiveFog = 1.00
        local smokeApproachFog = 0.95
        local gt = getGameTime and getGameTime() or nil
        local now = (gt and gt.getWorldAgeHours and gt:getWorldAgeHours()) or 0
        local startHour = HTT.toNumber(state.startHour, now)
        local elapsedHours = now - startHour
        local approachHours = HTT.secondsToWorldHours and HTT.secondsToWorldHours(30.0, 30.0) or (30.0 / 3600.0)
        if elapsedHours < approachHours then
            return smokeApproachFog, "smoke"
        end
        return smokeActiveFog, "smoke"
    end

    return 0, "none"
end

local function logFogModeTransition(climateMode)
    local state = HTT.serverEvent or {}
    local eventId = tostring(state.eventId or "")
    local phase = tostring(state.toxicPhase or "")
    local active = state.active == true
    local prevMode = lastFogDebugMode

    if climateMode == lastFogDebugMode
        and eventId == lastFogDebugEventId
        and phase == lastFogDebugPhase
        and active == lastFogDebugActive
    then
        return
    end

    lastFogDebugMode = climateMode
    lastFogDebugEventId = eventId
    lastFogDebugPhase = phase
    lastFogDebugActive = active

    if climateMode == "toxic" then
        HTT.log(
            "Event fog source=toxic active="
                .. tostring(active)
                .. " phase="
                .. tostring(phase ~= "" and phase or "none")
        )
        logFogControllerSnapshot("toxic-" .. tostring(phase ~= "" and phase or "none"))
        return
    end

    if climateMode == "smoke" then
        HTT.log("Event fog source=smoke_curtain_event (visual-only, non-toxic)")
        logFogControllerSnapshot("smoke")
        return
    end

    if climateMode == "none" then
        if eventId ~= "" then
            HTT.log("Event fog cleared for event=" .. tostring(eventId))
        elseif prevMode ~= "__init__" then
            HTT.log("Event fog cleared")
        end
        logFogControllerSnapshot("none")
    end
end

local function toxicFogTick()
    local targetFog, climateMode = getEventFogTarget()
    logFogModeTransition(climateMode)
    runLegacyFogMigrationIfNeeded(climateMode)

    if climateMode == "smoke" then
        clearToxicClimateStack()
        applySmokeClimateStack()
    elseif climateMode == "toxic" then
        clearSmokeClimateStack()
        applyToxicClimateStack()
    else
        clearSmokeClimateStack()
        clearToxicClimateStack()
    end

    setFogOverride(targetFog)
end

local fogTickHooked = registerEvent("OnTick", toxicFogTick)
if not fogTickHooked then
    registerEvent("OnClimateTick", toxicFogTick)
end

registerEvent("OnGameStart", function()
    legacyFogMigrationPending = true
    forceClearEventFog("game-start")
    HTT.log("Toxic fog renderer loaded")
end)
