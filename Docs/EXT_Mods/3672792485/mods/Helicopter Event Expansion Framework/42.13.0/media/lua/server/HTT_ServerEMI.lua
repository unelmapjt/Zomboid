require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerEMI = HTT.ServerEMI or {}

local EMI_SCRIPT_SIGNATURE = "2026-03-19-emi-world-vehicle-lights-v3"

if HTT._serverEMILoaded then
    if HTT and HTT.log then
        HTT.log("Server EMI chunk skipped (already loaded, signature=" .. EMI_SCRIPT_SIGNATURE .. ")")
    end
    return
end
HTT._serverEMILoaded = true

local EMI_APPROACH_SECONDS = 30.0
local EMI_PULSE_GAP_SECONDS = 3.0
local EMI_ROTOR_REPEAT_SECONDS = 30.0
local EMI_EFFECT_REAPPLY_SECONDS = 6.0
local EMI_FOLLOW_SYNC_SECONDS = 1.2
local EMI_RANGE_MULTIPLIER = 0.35
local EMI_MIN_SIGNAL_RANGE = 2.0
local EMI_TARGET_RADIUS = 40
local EMI_SOUND_RADIUS = 68
local EMI_RANGE_SYNC_EPSILON = 0.01
local EMI_LIGHT_STATE_EPSILON = 0.001
local EMI_LIGHT_UPDATE_SECONDS = 0.10
local EMI_LIGHT_FLICKER_MIN_SECONDS = 0.50
local EMI_LIGHT_FLICKER_MAX_SECONDS = 2.00
local EMI_LIGHT_CUT_MIN_SECONDS = 0.10
local EMI_LIGHT_CUT_MAX_SECONDS = 0.30
local EMI_LIGHT_DIM_FACTOR = 0.40
local EMI_LIGHT_FULL_OFF_CHANCE = 0.50
local EMI_LIGHT_BASE_FLICKER_CHANCE = 0.30
local EMI_LIGHT_EXTRA_NEAR_CENTER_CHANCE = 0.35
local EMI_WORLD_LIGHT_SCAN_RADIUS = 18
local EMI_WORLD_LIGHT_SCAN_Z_RANGE = 1
local EMI_BATTERY_DRAIN_PER_PULSE = 0.40

local EMI_LIGHT_KIND_ITEM = "item"
local EMI_LIGHT_KIND_SWITCH = "switch"
local EMI_LIGHT_KIND_VEHICLE = "vehicle"

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    pulseTwoHour = 0,
    firstPulsePlayed = false,
    secondPulsePlayed = false,
    nextRotorHour = 0,
    nextCenterSyncHour = 0,
    nextReapplyHour = 0,
    nextLightUpdateHour = 0,
    affectedRadios = {},
    affectedLights = {},
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.pulseTwoHour = 0
    runtime.firstPulsePlayed = false
    runtime.secondPulsePlayed = false
    runtime.nextRotorHour = 0
    runtime.nextCenterSyncHour = 0
    runtime.nextReapplyHour = 0
    runtime.nextLightUpdateHour = 0
    runtime.affectedRadios = {}
    runtime.affectedLights = {}
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

local function secondsToWorldHoursSafe(seconds, fallbackSeconds)
    local sec = HTT.toNumber(seconds, fallbackSeconds)
    if sec == nil or sec <= 0 then
        return 0
    end

    if HTT.secondsToWorldHours then
        local worldHours = HTT.secondsToWorldHours(sec, fallbackSeconds)
        if worldHours and worldHours > 0 then
            return worldHours
        end
    end

    return sec / 3600.0
end

local function getNowWorldHourSafe()
    local gt = getGameTime and getGameTime() or nil
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return gt:getWorldAgeHours()
end

local function resolveFollowPlayer(state)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        local wantedId = state and state.followOnlineId or nil
        if wantedId ~= nil then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p and not p:isDead() and p.getOnlineID and p:getOnlineID() == wantedId then
                    return p
                end
            end
        end

        local closest = nil
        local bestDist = nil
        local cx = HTT.toNumber(state and state.centerX, 0)
        local cy = HTT.toNumber(state and state.centerY, 0)
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() then
                local dx = p:getX() - cx
                local dy = p:getY() - cy
                local distSq = dx * dx + dy * dy
                if not bestDist or distSq < bestDist then
                    bestDist = distSq
                    closest = p
                end
            end
        end

        if closest and closest.getOnlineID then
            state.followOnlineId = closest:getOnlineID()
        end

        return closest
    end

    if getPlayer then
        local p = getPlayer()
        if p and not p:isDead() then
            return p
        end
    end

    return nil
end

local function updateDynamicCenter(state, now)
    if runtime.nextCenterSyncHour > 0 and now < runtime.nextCenterSyncHour then
        return
    end
    runtime.nextCenterSyncHour = now + secondsToWorldHoursSafe(
        EMI_FOLLOW_SYNC_SECONDS,
        EMI_FOLLOW_SYNC_SECONDS
    )

    local target = resolveFollowPlayer(state)
    if not target then
        return
    end

    local nx = target:getX()
    local ny = target:getY()
    local nz = target:getZ()
    local ox = HTT.toNumber(state.centerX, nx)
    local oy = HTT.toNumber(state.centerY, ny)
    local oz = HTT.toNumber(state.centerZ, nz)

    local moved = math.abs(nx - ox) > 0.5
        or math.abs(ny - oy) > 0.5
        or math.abs(nz - oz) > 0.1
    if moved then
        state.centerX = nx
        state.centerY = ny
        state.centerZ = nz
        if HTT.Server and HTT.Server.broadcastEventState then
            HTT.Server.broadcastEventState()
        end
    end
end

local function broadcastEMISound(state, soundName, radius, x, y, z)
    if not soundName or soundName == "" then
        return false
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return false
    end

    local baseRadius = math.max(
        HTT.toNumber(radius, EMI_SOUND_RADIUS),
        math.max(EMI_SOUND_RADIUS, HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius))
    )
    return HTT.Server.broadcastSound(
        soundName,
        HTT.toNumber(x, state.centerX),
        HTT.toNumber(y, state.centerY),
        HTT.toNumber(z, state.centerZ),
        baseRadius,
        {
            eventId = state and state.eventId or "electromagnetic_interference_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function restoreRadioRanges()
    for item, entry in pairs(runtime.affectedRadios) do
        if item and entry and item.getDeviceData then
            local okData, deviceData = pcall(function()
                return item:getDeviceData()
            end)
            if okData and deviceData then
                if entry.tx ~= nil
                    and entry.appliedTx ~= nil
                    and entry.overrideTx ~= true
                    and deviceData.setTransmitRange
                then
                    local currentTx = nil
                    if deviceData.getTransmitRange then
                        local okCurrent, value = pcall(function()
                            return deviceData:getTransmitRange()
                        end)
                        if okCurrent then
                            currentTx = HTT.toNumber(value, nil)
                        end
                    end
                    if currentTx == nil or math.abs(currentTx - entry.appliedTx) <= EMI_RANGE_SYNC_EPSILON then
                        pcall(function()
                            deviceData:setTransmitRange(entry.tx)
                        end)
                    end
                end
                if entry.mic ~= nil
                    and entry.appliedMic ~= nil
                    and entry.overrideMic ~= true
                    and deviceData.setMicRange
                then
                    local currentMic = nil
                    if deviceData.getMicRange then
                        local okCurrent, value = pcall(function()
                            return deviceData:getMicRange()
                        end)
                        if okCurrent then
                            currentMic = HTT.toNumber(value, nil)
                        end
                    end
                    if currentMic == nil or math.abs(currentMic - entry.appliedMic) <= EMI_RANGE_SYNC_EPSILON then
                        pcall(function()
                            deviceData:setMicRange(entry.mic)
                        end)
                    end
                end
                if entry.wasOn == true and entry.appliedOff == true and deviceData.setIsTurnedOn then
                    local currentOn = nil
                    if deviceData.getIsTurnedOn then
                        local okCurrent, value = pcall(function()
                            return deviceData:getIsTurnedOn()
                        end)
                        if okCurrent then
                            currentOn = value == true
                        end
                    end
                    if currentOn == nil or currentOn == false then
                        pcall(function()
                            deviceData:setIsTurnedOn(true)
                        end)
                    end
                end
            end
        end

        if item and entry and entry.wasActivated == true and entry.appliedActivatedOff == true and item.setActivated then
            local currentActivated = nil
            if item.isActivated then
                local okCurrent, value = pcall(function()
                    return item:isActivated()
                end)
                if okCurrent then
                    currentActivated = value == true
                end
            end
            if currentActivated == nil or currentActivated == false then
                pcall(function()
                    item:setActivated(true)
                end)
            end
        end
    end
    runtime.affectedRadios = {}
end

local function getLightDistanceSafe(item)
    if not item or not item.getLightDistance then
        return nil
    end

    local ok, value = pcall(function()
        return item:getLightDistance()
    end)
    if not ok or value == nil then
        return nil
    end
    return HTT.toNumber(value, nil)
end

local function getLightStrengthSafe(item)
    if not item or not item.getLightStrength then
        return nil
    end

    local ok, value = pcall(function()
        return item:getLightStrength()
    end)
    if not ok or value == nil then
        return nil
    end
    return HTT.toNumber(value, nil)
end

local function setLightDistanceSafe(item, value)
    if not item or not item.setLightDistance or value == nil then
        return false
    end

    local ok = pcall(function()
        item:setLightDistance(value)
    end)
    return ok == true
end

local function setLightStrengthSafe(item, value)
    if not item or not item.setLightStrength or value == nil then
        return false
    end

    local ok = pcall(function()
        item:setLightStrength(value)
    end)
    return ok == true
end

local function isActivatedLightSafe(item)
    if not item or not item.isActivated then
        return false
    end

    local ok, value = pcall(function()
        return item:isActivated()
    end)
    return ok and value == true
end

local function isInstanceOfSafe(obj, className)
    if not obj or not className or className == "" or not instanceof then
        return false
    end

    local ok, value = pcall(function()
        return instanceof(obj, className)
    end)
    return ok and value == true
end

local function isLightSwitchActivatedSafe(lightSwitch)
    if not lightSwitch or not lightSwitch.isActivated then
        return false
    end

    local ok, value = pcall(function()
        return lightSwitch:isActivated()
    end)
    return ok and value == true
end

local function setLightSwitchActiveSafe(lightSwitch, active)
    if not lightSwitch or not lightSwitch.setActive then
        return false
    end

    local desired = active == true
    local ok = pcall(function()
        lightSwitch:setActive(desired)
    end)
    if not ok then
        return false
    end

    return isLightSwitchActivatedSafe(lightSwitch) == desired
end

local function isWorldLightSwitchCandidate(lightSwitch)
    if not isInstanceOfSafe(lightSwitch, "IsoLightSwitch") then
        return false
    end
    return isLightSwitchActivatedSafe(lightSwitch)
end

local function getVehicleHeadlightsOnSafe(vehicle)
    if not vehicle or not vehicle.getHeadlightsOn then
        return false
    end

    local ok, value = pcall(function()
        return vehicle:getHeadlightsOn()
    end)
    return ok and value == true
end

local function setVehicleHeadlightsOnSafe(vehicle, active)
    if not vehicle or not vehicle.setHeadlightsOn then
        return false
    end

    local desired = active == true
    local ok = pcall(function()
        vehicle:setHeadlightsOn(desired)
    end)
    if not ok then
        return false
    end

    return getVehicleHeadlightsOnSafe(vehicle) == desired
end

local function getVehicleLightbarModeSafe(vehicle)
    if not vehicle or not vehicle.getLightbarLightsMode then
        return 0
    end

    local ok, value = pcall(function()
        return vehicle:getLightbarLightsMode()
    end)
    if not ok then
        return 0
    end
    return math.max(0, math.floor(HTT.toNumber(value, 0)))
end

local function setVehicleLightbarModeSafe(vehicle, mode)
    if not vehicle or not vehicle.setLightbarLightsMode then
        return false
    end

    local desired = math.max(0, math.floor(HTT.toNumber(mode, 0)))
    local ok = pcall(function()
        vehicle:setLightbarLightsMode(desired)
    end)
    if not ok then
        return false
    end

    return getVehicleLightbarModeSafe(vehicle) == desired
end

local function isVehicleLightCandidate(vehicle)
    if not isInstanceOfSafe(vehicle, "BaseVehicle") then
        return false
    end
    if getVehicleHeadlightsOnSafe(vehicle) then
        return true
    end
    return getVehicleLightbarModeSafe(vehicle) > 0
end

local function isExcludedNonElectricLight(item)
    if not item or not item.getFullType then
        return false
    end

    local fullType = tostring(item:getFullType() or "")
    if fullType == "Base.Candle"
        or fullType == "Base.CandleLit"
        or fullType == "Base.Lantern_Hurricane"
        or fullType == "Base.Lantern_HurricaneLit"
    then
        return true
    end

    if item.hasTag and ItemTag and ItemTag.LIT_LANTERN then
        local okTag, tagged = pcall(function()
            return item:hasTag(ItemTag.LIT_LANTERN)
        end)
        if okTag and tagged == true then
            return true
        end
    end

    if item.hasTag and ItemTag and ItemTag.UNLIT_LANTERN then
        local okTag, tagged = pcall(function()
            return item:hasTag(ItemTag.UNLIT_LANTERN)
        end)
        if okTag and tagged == true then
            return true
        end
    end

    return false
end

local function isElectricLightCandidate(item)
    if not item then
        return false
    end
    if isExcludedNonElectricLight(item) then
        return false
    end
    if not item.canEmitLight or not item.canBeActivated then
        return false
    end

    local okEmit, canEmit = pcall(function()
        return item:canEmitLight()
    end)
    if not okEmit or canEmit ~= true then
        return false
    end

    local okCanActivate, canActivate = pcall(function()
        return item:canBeActivated()
    end)
    if not okCanActivate or canActivate ~= true then
        return false
    end

    local baseDistance = getLightDistanceSafe(item)
    local baseStrength = getLightStrengthSafe(item)
    if baseDistance == nil and baseStrength == nil then
        return false
    end

    return true
end

local function getNextLightFlickerHour(now)
    local delaySeconds = ZombRandFloat(EMI_LIGHT_FLICKER_MIN_SECONDS, EMI_LIGHT_FLICKER_MAX_SECONDS)
    return HTT.toNumber(now, 0) + secondsToWorldHoursSafe(delaySeconds, delaySeconds)
end

local function getLightCutEndHour(now)
    local delaySeconds = ZombRandFloat(EMI_LIGHT_CUT_MIN_SECONDS, EMI_LIGHT_CUT_MAX_SECONDS)
    return HTT.toNumber(now, 0) + secondsToWorldHoursSafe(delaySeconds, delaySeconds)
end

local function restoreLightEntry(item, entry)
    if not item or not entry then
        return false
    end

    if entry.kind == EMI_LIGHT_KIND_SWITCH then
        local changed = false
        if entry.baseActivated ~= nil then
            changed = setLightSwitchActiveSafe(item, entry.baseActivated == true)
        end
        entry.appliedMode = nil
        entry.restoreHour = 0
        return changed
    end

    if entry.kind == EMI_LIGHT_KIND_VEHICLE then
        local changed = false
        if entry.baseHeadlightsOn ~= nil then
            changed = setVehicleHeadlightsOnSafe(item, entry.baseHeadlightsOn == true) or changed
        end
        if entry.baseLightbarMode ~= nil then
            changed = setVehicleLightbarModeSafe(item, entry.baseLightbarMode) or changed
        end
        entry.appliedMode = nil
        entry.restoreHour = 0
        return changed
    end

    local changed = false
    if entry.baseDistance ~= nil then
        if setLightDistanceSafe(item, entry.baseDistance) then
            changed = true
        end
    end
    if entry.baseStrength ~= nil then
        if setLightStrengthSafe(item, entry.baseStrength) then
            changed = true
        end
    end

    entry.appliedMode = nil
    entry.restoreHour = 0
    return changed
end

local function restoreLightStates()
    for item, entry in pairs(runtime.affectedLights) do
        if item and entry then
            restoreLightEntry(item, entry)
        end
    end
    runtime.affectedLights = {}
end

local function captureLightEntry(item, now, kind)
    local entry = runtime.affectedLights[item]
    if entry then
        return entry
    end

    local lightKind = kind or EMI_LIGHT_KIND_ITEM
    entry = {
        kind = lightKind,
        appliedMode = nil,
        restoreHour = 0,
        nextFlickerHour = getNextLightFlickerHour(now),
    }
    if lightKind == EMI_LIGHT_KIND_SWITCH then
        entry.baseActivated = isLightSwitchActivatedSafe(item)
    elseif lightKind == EMI_LIGHT_KIND_VEHICLE then
        entry.baseHeadlightsOn = getVehicleHeadlightsOnSafe(item)
        entry.baseLightbarMode = getVehicleLightbarModeSafe(item)
    else
        entry.baseDistance = getLightDistanceSafe(item)
        entry.baseStrength = getLightStrengthSafe(item)
    end
    runtime.affectedLights[item] = entry
    return entry
end

local function refreshLightBaseline(item, entry)
    if not item or not entry then
        return
    end
    if HTT.toNumber(entry.restoreHour, 0) > 0 then
        return
    end

    if entry.kind == EMI_LIGHT_KIND_SWITCH then
        entry.baseActivated = isLightSwitchActivatedSafe(item)
        return
    end

    if entry.kind == EMI_LIGHT_KIND_VEHICLE then
        entry.baseHeadlightsOn = getVehicleHeadlightsOnSafe(item)
        entry.baseLightbarMode = getVehicleLightbarModeSafe(item)
        return
    end

    local currentDistance = getLightDistanceSafe(item)
    if currentDistance ~= nil and currentDistance > EMI_LIGHT_STATE_EPSILON then
        entry.baseDistance = currentDistance
    end

    local currentStrength = getLightStrengthSafe(item)
    if currentStrength ~= nil and currentStrength > EMI_LIGHT_STATE_EPSILON then
        entry.baseStrength = currentStrength
    end
end

local function applyLightDisruption(item, entry, now)
    if not item or not entry then
        return false
    end

    if entry.kind == EMI_LIGHT_KIND_SWITCH then
        if entry.baseActivated ~= true then
            return false
        end

        local changed = setLightSwitchActiveSafe(item, false)
        if not changed then
            return false
        end

        entry.appliedMode = "off"
        entry.restoreHour = getLightCutEndHour(now)
        return true
    end

    if entry.kind == EMI_LIGHT_KIND_VEHICLE then
        local changed = false
        if entry.baseHeadlightsOn == true then
            changed = setVehicleHeadlightsOnSafe(item, false) or changed
        end
        if HTT.toNumber(entry.baseLightbarMode, 0) > 0 then
            changed = setVehicleLightbarModeSafe(item, 0) or changed
        end
        if not changed then
            return false
        end

        entry.appliedMode = "off"
        entry.restoreHour = getLightCutEndHour(now)
        return true
    end

    local offMode = ZombRandFloat(0, 1) < EMI_LIGHT_FULL_OFF_CHANCE
    local targetDistance = nil
    local targetStrength = nil
    local appliedMode = nil

    if offMode then
        targetDistance = 0
        targetStrength = 0
        appliedMode = "off"
    else
        if entry.baseDistance ~= nil then
            targetDistance = math.max(0, entry.baseDistance * EMI_LIGHT_DIM_FACTOR)
        end
        if entry.baseStrength ~= nil then
            targetStrength = math.max(0, entry.baseStrength * EMI_LIGHT_DIM_FACTOR)
        end
        appliedMode = "dim"
    end

    local changed = false
    if targetDistance ~= nil then
        if setLightDistanceSafe(item, targetDistance) then
            changed = true
        end
    end
    if targetStrength ~= nil then
        if setLightStrengthSafe(item, targetStrength) then
            changed = true
        end
    end
    if not changed then
        return false
    end

    entry.appliedMode = appliedMode
    entry.restoreHour = getLightCutEndHour(now)
    return true
end

local function computeDistanceWeightedFlickerChance(state, player)
    local px = HTT.toNumber(player and player.getX and player:getX() or nil, HTT.toNumber(state and state.centerX, 0))
    local py = HTT.toNumber(player and player.getY and player:getY() or nil, HTT.toNumber(state and state.centerY, 0))
    local cx = HTT.toNumber(state and state.centerX, px)
    local cy = HTT.toNumber(state and state.centerY, py)

    local dx = px - cx
    local dy = py - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local norm = 1.0
    if EMI_TARGET_RADIUS > 0 then
        norm = math.min(1.0, dist / EMI_TARGET_RADIUS)
    end

    local chance = EMI_LIGHT_BASE_FLICKER_CHANCE + ((1.0 - norm) * EMI_LIGHT_EXTRA_NEAR_CENTER_CHANCE)
    if chance < 0.05 then
        chance = 0.05
    elseif chance > 0.95 then
        chance = 0.95
    end
    return chance
end

local function isPortableLightTracked(item)
    if not isElectricLightCandidate(item) then
        return false
    end
    return runtime.affectedLights[item] ~= nil or isActivatedLightSafe(item)
end

local function isLightTargetCurrentlyActive(target, kind)
    if kind == EMI_LIGHT_KIND_SWITCH then
        return isWorldLightSwitchCandidate(target)
    end
    if kind == EMI_LIGHT_KIND_VEHICLE then
        return isVehicleLightCandidate(target)
    end
    return isElectricLightCandidate(target) and isActivatedLightSafe(target)
end

local enumerateInventoryItems

local function collectPortableLightTargets(container, out)
    if not container or not out then
        return
    end

    local allItems = {}
    enumerateInventoryItems(container, allItems)
    for i = 1, #allItems do
        local item = allItems[i]
        if isPortableLightTracked(item) then
            out[#out + 1] = item
        end
    end
end

local function collectNearbyWorldLightTargets(cell, centerX, centerY, centerZ, out)
    if not cell or not out then
        return
    end

    local scanRadius = EMI_WORLD_LIGHT_SCAN_RADIUS
    local scanRadiusSq = scanRadius * scanRadius
    local baseX = math.floor(HTT.toNumber(centerX, 0))
    local baseY = math.floor(HTT.toNumber(centerY, 0))
    local baseZ = math.floor(HTT.toNumber(centerZ, 0))
    local minZ = math.max(0, baseZ - EMI_WORLD_LIGHT_SCAN_Z_RANGE)
    local maxZ = baseZ + EMI_WORLD_LIGHT_SCAN_Z_RANGE

    for sx = baseX - scanRadius, baseX + scanRadius do
        local dx = sx - centerX
        local dxSq = dx * dx
        if dxSq <= scanRadiusSq then
            for sy = baseY - scanRadius, baseY + scanRadius do
                local dy = sy - centerY
                if (dxSq + (dy * dy)) <= scanRadiusSq then
                    for sz = minZ, maxZ do
                        local square = cell.getGridSquare and cell:getGridSquare(sx, sy, sz) or nil
                        if square and square.getObjects then
                            local objects = square:getObjects()
                            if objects then
                                for i = 0, objects:size() - 1 do
                                    local obj = objects:get(i)
                                    if isInstanceOfSafe(obj, "IsoLightSwitch")
                                        and (runtime.affectedLights[obj] ~= nil or isLightSwitchActivatedSafe(obj))
                                    then
                                        out[#out + 1] = obj
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function collectNearbyVehicleLightTargets(cell, centerX, centerY, out)
    if not cell or not cell.getVehicles or not out then
        return
    end

    local vehicles = cell:getVehicles()
    if not vehicles then
        return
    end

    local scanRadiusSq = EMI_WORLD_LIGHT_SCAN_RADIUS * EMI_WORLD_LIGHT_SCAN_RADIUS
    for i = 0, vehicles:size() - 1 do
        local vehicle = vehicles:get(i)
        if vehicle then
            local vx = HTT.toNumber(vehicle.getX and vehicle:getX() or nil, nil)
            local vy = HTT.toNumber(vehicle.getY and vehicle:getY() or nil, nil)
            if vx ~= nil and vy ~= nil then
                local dx = vx - centerX
                local dy = vy - centerY
                if (dx * dx + dy * dy) <= scanRadiusSq
                    and (runtime.affectedLights[vehicle] ~= nil or isVehicleLightCandidate(vehicle))
                then
                    out[#out + 1] = vehicle
                end
            end
        end
    end
end

local function processLightTarget(target, kind, now, seen, flickerChance)
    if not target then
        return
    end

    local entry = captureLightEntry(target, now, kind)
    seen[target] = true

    if HTT.toNumber(entry.restoreHour, 0) > 0 and now >= HTT.toNumber(entry.restoreHour, 0) then
        restoreLightEntry(target, entry)
    end

    if HTT.toNumber(entry.restoreHour, 0) <= 0 then
        refreshLightBaseline(target, entry)

        if isLightTargetCurrentlyActive(target, kind) then
            local nextFlicker = HTT.toNumber(entry.nextFlickerHour, 0)
            if nextFlicker <= 0 or now >= nextFlicker then
                entry.nextFlickerHour = getNextLightFlickerHour(now)
                local chanceJitter = ZombRandFloat(-0.05, 0.05)
                local rollChance = flickerChance + chanceJitter
                if rollChance < 0.05 then
                    rollChance = 0.05
                elseif rollChance > 0.95 then
                    rollChance = 0.95
                end

                if ZombRandFloat(0, 1) < rollChance then
                    applyLightDisruption(target, entry, now)
                end
            end
        end
    end
end

local function updateEMILights(state, now)
    local nextUpdate = HTT.toNumber(runtime.nextLightUpdateHour, 0)
    if nextUpdate > 0 and now < nextUpdate then
        return
    end
    runtime.nextLightUpdateHour = now + secondsToWorldHoursSafe(
        EMI_LIGHT_UPDATE_SECONDS,
        EMI_LIGHT_UPDATE_SECONDS
    )

    local player = resolveFollowPlayer(state)
    if not player or player:isDead() then
        restoreLightStates()
        return
    end
    if not player.getInventory then
        restoreLightStates()
        return
    end

    local inv = player:getInventory()
    if not inv then
        restoreLightStates()
        return
    end

    local cell = getCell and getCell() or nil
    if not cell then
        restoreLightStates()
        return
    end

    local px = player:getX()
    local py = player:getY()
    local dx = px - HTT.toNumber(state.centerX, px)
    local dy = py - HTT.toNumber(state.centerY, py)
    if (dx * dx + dy * dy) > (EMI_TARGET_RADIUS * EMI_TARGET_RADIUS) then
        restoreLightStates()
        return
    end

    local flickerChance = computeDistanceWeightedFlickerChance(state, player)
    local seen = {}

    local portableTargets = {}
    collectPortableLightTargets(inv, portableTargets)
    for i = 1, #portableTargets do
        processLightTarget(portableTargets[i], EMI_LIGHT_KIND_ITEM, now, seen, flickerChance)
    end

    local worldLightTargets = {}
    collectNearbyWorldLightTargets(cell, px, py, player:getZ(), worldLightTargets)
    for i = 1, #worldLightTargets do
        processLightTarget(worldLightTargets[i], EMI_LIGHT_KIND_SWITCH, now, seen, flickerChance)
    end

    local vehicleTargets = {}
    collectNearbyVehicleLightTargets(cell, px, py, vehicleTargets)
    for i = 1, #vehicleTargets do
        processLightTarget(vehicleTargets[i], EMI_LIGHT_KIND_VEHICLE, now, seen, flickerChance)
    end

    for item, entry in pairs(runtime.affectedLights) do
        if not seen[item] then
            if item and entry then
                restoreLightEntry(item, entry)
            end
            runtime.affectedLights[item] = nil
        end
    end
end

local function isSmallBatteryItem(item)
    if not item or not item.getFullType then
        return false
    end

    return tostring(item:getFullType() or "") == "Base.Battery"
end

local function getItemMethodSafe(item, methodName)
    if not item or not methodName or methodName == "" then
        return nil
    end

    local method = nil
    local ok = pcall(function()
        method = item[methodName]
    end)
    if ok and type(method) == "function" then
        return method
    end
    return nil
end

local function callItemGetterSafe(item, methodName)
    local method = getItemMethodSafe(item, methodName)
    if not method then
        return false, nil
    end

    local ok, value = pcall(method, item)
    if not ok then
        return false, nil
    end
    return true, value
end

local function callItemSetterSafe(item, methodName, value)
    local method = getItemMethodSafe(item, methodName)
    if not method then
        return false
    end

    local ok = pcall(method, item, value)
    return ok == true
end

local function isPortableRadioItem(item)
    if not item then
        return false
    end

    if item.getScriptItem and ItemType and ItemType.RADIO then
        local okScript, scriptItem = pcall(function()
            return item:getScriptItem()
        end)
        if okScript and scriptItem and scriptItem.isItemType then
            local okType, isRadio = pcall(function()
                return scriptItem:isItemType(ItemType.RADIO)
            end)
            if okType and isRadio == true then
                return true
            end
        end
    end

    if item.getFullType then
        local fullType = tostring(item:getFullType() or "")
        if string.find(fullType, "Walkie", 1, true)
            or string.find(fullType, "HamRadio", 1, true)
            or string.find(fullType, "Radio", 1, true)
        then
            return true
        end
    end

    return false
end

enumerateInventoryItems = function(container, out)
    if not container or not out then
        return
    end

    local items = container.getItems and container:getItems() or nil
    if not items then
        return
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            out[#out + 1] = item
            if item.IsInventoryContainer and item:IsInventoryContainer() then
                local sub = item.getInventory and item:getInventory() or nil
                if not sub and item.getItemContainer then
                    sub = item:getItemContainer()
                end
                if sub then
                    enumerateInventoryItems(sub, out)
                end
            end
        end
    end
end

local function getPortableDeviceData(item)
    if not item or not item.getDeviceData then
        return nil
    end

    if not isPortableRadioItem(item) then
        return nil
    end

    local okDevice, deviceData = pcall(function()
        return item:getDeviceData()
    end)
    if not okDevice or not deviceData then
        return nil
    end

    if deviceData.getIsPortable then
        local okPortable, isPortable = pcall(function()
            return deviceData:getIsPortable()
        end)
        if okPortable and isPortable == false then
            return nil
        end
    end

    if deviceData.getIsTelevision then
        local okTv, isTv = pcall(function()
            return deviceData:getIsTelevision()
        end)
        if okTv and isTv == true then
            return nil
        end
    end

    return deviceData
end

local function captureRadioOriginalRange(item, deviceData)
    local existing = runtime.affectedRadios[item]
    if existing then
        return existing
    end

    local entry = {
        tx = nil,
        mic = nil,
        appliedTx = nil,
        appliedMic = nil,
        overrideTx = false,
        overrideMic = false,
        wasOn = nil,
        appliedOff = false,
        wasActivated = nil,
        appliedActivatedOff = false,
    }
    if deviceData.getTransmitRange then
        local ok, value = pcall(function()
            return deviceData:getTransmitRange()
        end)
        if ok and value ~= nil then
            entry.tx = HTT.toNumber(value, nil)
        end
    end
    if deviceData.getMicRange then
        local ok, value = pcall(function()
            return deviceData:getMicRange()
        end)
        if ok and value ~= nil then
            entry.mic = HTT.toNumber(value, nil)
        end
    end
    if deviceData.getIsTurnedOn then
        local ok, value = pcall(function()
            return deviceData:getIsTurnedOn()
        end)
        if ok then
            entry.wasOn = value == true
        end
    end
    if item and item.isActivated then
        local ok, value = pcall(function()
            return item:isActivated()
        end)
        if ok then
            entry.wasActivated = value == true
        end
    end

    runtime.affectedRadios[item] = entry
    return entry
end

local function applyRadioEMIPenalty(item, deviceData)
    local entry = captureRadioOriginalRange(item, deviceData)
    local changed = false

    if entry.tx and entry.tx > 0 and entry.overrideTx ~= true and deviceData.setTransmitRange then
        local currentTx = nil
        if entry.appliedTx ~= nil and deviceData.getTransmitRange then
            local okCurrent, value = pcall(function()
                return deviceData:getTransmitRange()
            end)
            if okCurrent then
                currentTx = HTT.toNumber(value, nil)
            end
        end
        if currentTx ~= nil and math.abs(currentTx - entry.appliedTx) > EMI_RANGE_SYNC_EPSILON then
            entry.overrideTx = true
            entry.appliedTx = nil
        else
            local newTx = math.max(EMI_MIN_SIGNAL_RANGE, entry.tx * EMI_RANGE_MULTIPLIER)
            pcall(function()
                deviceData:setTransmitRange(newTx)
            end)
            entry.appliedTx = newTx
            changed = true
        end
    end

    if entry.mic and entry.mic > 0 and entry.overrideMic ~= true and deviceData.setMicRange then
        local currentMic = nil
        if entry.appliedMic ~= nil and deviceData.getMicRange then
            local okCurrent, value = pcall(function()
                return deviceData:getMicRange()
            end)
            if okCurrent then
                currentMic = HTT.toNumber(value, nil)
            end
        end
        if currentMic ~= nil and math.abs(currentMic - entry.appliedMic) > EMI_RANGE_SYNC_EPSILON then
            entry.overrideMic = true
            entry.appliedMic = nil
        else
            local newMic = math.max(EMI_MIN_SIGNAL_RANGE, entry.mic * EMI_RANGE_MULTIPLIER)
            pcall(function()
                deviceData:setMicRange(newMic)
            end)
            entry.appliedMic = newMic
            changed = true
        end
    end

    if deviceData.setIsTurnedOn and deviceData.getIsTurnedOn then
        local okOn, turnedOn = pcall(function()
            return deviceData:getIsTurnedOn()
        end)
        if okOn and turnedOn then
            local okOff = pcall(function()
                deviceData:setIsTurnedOn(false)
            end)
            if okOff then
                entry.appliedOff = true
                changed = true
            end
        end
    end

    if item and item.isActivated and item.setActivated then
        local okOn, activated = pcall(function()
            return item:isActivated()
        end)
        if okOn and activated == true then
            local okOff = pcall(function()
                item:setActivated(false)
            end)
            if okOff then
                entry.appliedActivatedOff = true
                changed = true
            end
        end
    end

    return changed
end

local function getBatteryUsedDelta(item)
    if not item then
        return nil
    end

    local okUsedDelta, usedDelta = callItemGetterSafe(item, "getUsedDelta")
    if okUsedDelta and usedDelta ~= nil then
        return HTT.toNumber(usedDelta, nil)
    end

    local okCurrentUses, currentUses = callItemGetterSafe(item, "getCurrentUsesFloat")
    if okCurrentUses and currentUses ~= nil then
        local uses = HTT.toNumber(currentUses, nil)
        if uses ~= nil then
            if uses <= 1.001 then
                return math.max(0, math.min(1, uses))
            end

            local okUseDelta, useDelta = callItemGetterSafe(item, "getUseDelta")
            useDelta = okUseDelta and HTT.toNumber(useDelta, nil) or nil
            if useDelta ~= nil and useDelta > 0 then
                return math.max(0, math.min(1, uses * useDelta))
            end
        end
    end

    local okDelta, delta = callItemGetterSafe(item, "getDelta")
    if okDelta and delta ~= nil then
        return HTT.toNumber(delta, nil)
    end

    return nil
end

local function setBatteryUsedDelta(item, value)
    if not item or value == nil then
        return false
    end

    local target = math.max(0, math.min(1, HTT.toNumber(value, 0)))
    local okUsedDelta = callItemSetterSafe(item, "setUsedDelta", target)
    if okUsedDelta then
        return true
    end

    local okSetDelta = callItemSetterSafe(item, "setDelta", target)
    if okSetDelta then
        return true
    end

    local okUseDelta, useDelta = callItemGetterSafe(item, "getUseDelta")
    useDelta = okUseDelta and HTT.toNumber(useDelta, nil) or nil
    if getItemMethodSafe(item, "setCurrentUses") and useDelta ~= nil and useDelta > 0 then
        local uses = math.max(0, target / useDelta)
        local okCurrentUses = callItemSetterSafe(item, "setCurrentUses", uses)
        if okCurrentUses then
            return true
        end
    end

    return false
end

local function drainBatteryItem(item, amount)
    if not item then
        return false
    end

    local current = getBatteryUsedDelta(item)
    if current == nil then
        return false
    end

    local drainAmount = HTT.toNumber(amount, EMI_BATTERY_DRAIN_PER_PULSE)
    if drainAmount <= 0 then
        return false
    end

    local nextDelta = math.max(0, current - drainAmount)
    if nextDelta >= current then
        return false
    end

    return setBatteryUsedDelta(item, nextDelta)
end

local function applyEMIToPlayer(player, drainBatteries)
    if not player or player:isDead() or not player.getInventory then
        return 0, 0, 0, 0
    end

    local inv = player:getInventory()
    if not inv then
        return 0, 0, 0, 0
    end

    local allItems = {}
    enumerateInventoryItems(inv, allItems)

    local radiosDetected = 0
    local radiosAffected = 0
    local batteryCandidates = 0
    local batteriesDrained = 0
    for i = 1, #allItems do
        local item = allItems[i]

        local deviceData = getPortableDeviceData(item)
        if deviceData then
            radiosDetected = radiosDetected + 1
            if applyRadioEMIPenalty(item, deviceData) then
                radiosAffected = radiosAffected + 1
            end
        end

        if drainBatteries and isSmallBatteryItem(item) then
            batteryCandidates = batteryCandidates + 1
            if drainBatteryItem(item, EMI_BATTERY_DRAIN_PER_PULSE) then
                batteriesDrained = batteriesDrained + 1
            end
        end
    end

    return radiosDetected, radiosAffected, batteryCandidates, batteriesDrained
end

local function playRotorLoopIfNeeded(state, eventDef, now)
    local nextRotor = HTT.toNumber(runtime.nextRotorHour, 0)
    if nextRotor > 0 and now < nextRotor then
        return
    end

    runtime.nextRotorHour = now + secondsToWorldHoursSafe(
        EMI_ROTOR_REPEAT_SECONDS,
        EMI_ROTOR_REPEAT_SECONDS
    )

    local rotorSound = eventDef and eventDef.startSound or "HTT_loop_electromagnetic_interference"
    local rotorRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 24,
        EMI_SOUND_RADIUS
    )
    broadcastEMISound(state, rotorSound, rotorRadius)
end

local function applyPulseEffect(state, eventDef, now, secondPulse)
    local pulseSound = nil
    if secondPulse then
        pulseSound = eventDef and eventDef.hitSound or "HTT_electromagnetic_pulse_02"
    else
        pulseSound = eventDef and eventDef.fireSound or "HTT_electromagnetic_pulse_01"
    end

    local pulseRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 24,
        EMI_SOUND_RADIUS
    )
    broadcastEMISound(state, pulseSound, pulseRadius)

    local player = resolveFollowPlayer(state)
    if not player then
        return
    end

    local px = player:getX()
    local py = player:getY()
    local dx = px - HTT.toNumber(state.centerX, px)
    local dy = py - HTT.toNumber(state.centerY, py)
    if (dx * dx + dy * dy) > (EMI_TARGET_RADIUS * EMI_TARGET_RADIUS) then
        return
    end

    local radiosDetected, radiosAffected, batteryCandidates, batteriesDrained = applyEMIToPlayer(player, true)
    runtime.nextReapplyHour = now + secondsToWorldHoursSafe(
        EMI_EFFECT_REAPPLY_SECONDS,
        EMI_EFFECT_REAPPLY_SECONDS
    )

    HTT.log(string.format(
        "EMI pulse applied radiosDetected=%d radiosAffected=%d batteryCandidates=%d batteriesDrained=%d secondPulse=%s player=%s",
        radiosDetected,
        radiosAffected,
        batteryCandidates,
        batteriesDrained,
        tostring(secondPulse),
        tostring(player and player:getUsername() or "n/a")
    ))
end

local function reapplyRangePenaltyIfNeeded(state, now)
    local nextReapply = HTT.toNumber(runtime.nextReapplyHour, 0)
    if nextReapply <= 0 or now < nextReapply then
        return
    end

    local player = resolveFollowPlayer(state)
    if not player then
        runtime.nextReapplyHour = now + secondsToWorldHoursSafe(
            EMI_EFFECT_REAPPLY_SECONDS,
            EMI_EFFECT_REAPPLY_SECONDS
        )
        return
    end

    applyEMIToPlayer(player, false)
    runtime.nextReapplyHour = now + secondsToWorldHoursSafe(
        EMI_EFFECT_REAPPLY_SECONDS,
        EMI_EFFECT_REAPPLY_SECONDS
    )
end

local function emiTick()
    if not HTT.Server or not HTT.Server.state then
        restoreRadioRanges()
        restoreLightStates()
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "electromagnetic_interference_event" then
        restoreRadioRanges()
        restoreLightStates()
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                {
                    "actionHour",
                    "pulseTwoHour",
                    "nextRotorHour",
                    "nextCenterSyncHour",
                    "nextReapplyHour",
                    "nextLightUpdateHour",
                },
                now
            )
        end
        return
    end
    if now >= state.endHour then
        if HTT.Server and HTT.Server.stopEvent then
            HTT.Server.stopEvent("duration-expired")
        end
        restoreRadioRanges()
        restoreLightStates()
        resetRuntime()
        return
    end

    local eventDef = HTT.getEventDefinition("electromagnetic_interference_event")
    if not eventDef then
        return
    end

    local eventStart = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStart then
        runtime.eventStartHour = eventStart
        runtime.actionHour = eventStart + secondsToWorldHoursSafe(
            EMI_APPROACH_SECONDS,
            EMI_APPROACH_SECONDS
        )
        runtime.pulseTwoHour = runtime.actionHour + secondsToWorldHoursSafe(
            EMI_PULSE_GAP_SECONDS,
            EMI_PULSE_GAP_SECONDS
        )
        runtime.firstPulsePlayed = false
        runtime.secondPulsePlayed = false
        runtime.nextRotorHour = eventStart + secondsToWorldHoursSafe(
            EMI_ROTOR_REPEAT_SECONDS,
            EMI_ROTOR_REPEAT_SECONDS
        )
        runtime.nextCenterSyncHour = 0
        runtime.nextReapplyHour = 0
        runtime.nextLightUpdateHour = 0
        runtime.affectedRadios = {}
        runtime.affectedLights = {}
    end

    updateDynamicCenter(state, now)
    playRotorLoopIfNeeded(state, eventDef, now)

    local actionHour = HTT.toNumber(runtime.actionHour, now)
    if now >= actionHour and not runtime.firstPulsePlayed then
        runtime.firstPulsePlayed = true
        applyPulseEffect(state, eventDef, now, false)
    end

    if runtime.firstPulsePlayed and not runtime.secondPulsePlayed then
        local pulseTwoHour = HTT.toNumber(runtime.pulseTwoHour, now + 1)
        if now >= pulseTwoHour then
            runtime.secondPulsePlayed = true
            applyPulseEffect(state, eventDef, now, true)
        end
    end

    if runtime.firstPulsePlayed then
        reapplyRangePenaltyIfNeeded(state, now)
        updateEMILights(state, now)
    end
end

local emiTickHooked = registerEvent("OnTick", emiTick)
if not emiTickHooked then
    registerEvent("EveryOneMinute", emiTick)
end

registerEvent("OnGameStart", function()
    HTT.log(
        "Server EMI system loaded (hook="
            .. tostring(emiTickHooked and "OnTick" or "EveryOneMinute")
            .. ", signature="
            .. EMI_SCRIPT_SIGNATURE
            .. ")"
    )
end)
