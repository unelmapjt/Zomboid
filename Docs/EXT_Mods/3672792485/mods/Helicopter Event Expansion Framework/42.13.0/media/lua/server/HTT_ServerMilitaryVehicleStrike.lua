require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerMilitaryVehicleStrike = HTT.ServerMilitaryVehicleStrike or {}

if HTT._serverMilitaryVehicleStrikeLoaded then
    return
end
HTT._serverMilitaryVehicleStrikeLoaded = true

local STRIKE_APPROACH_SECONDS = 30.0
local STRIKE_WINDOW_SECONDS = 5.0
local FOLLOW_SYNC_SECONDS = 2.0

local MILITARY_EXACT_SCRIPTS = {
    ["base.pickupvanlightsmilitary"] = true,
    ["base.ambo"] = true,
    ["base.militarytruck"] = true,
}

local MILITARY_NAME_PATTERNS = {
    "military",
    "armored",
    "armour",
    "apc",
    "humvee",
    "m998",
    "m113",
    "vads",
    "btr",
}

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    finishHour = 0,
    strikeResolved = false,
    nextCenterSyncHour = 0,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.finishHour = 0
    runtime.strikeResolved = false
    runtime.nextCenterSyncHour = 0
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

local function getStrikeChancePercent()
    local chance = HTT.toNumber(HTT.Config and HTT.Config.MilitaryVehicleStrikeChance, 100)
    if chance == nil then
        chance = 100
    end
    if chance < 0 then
        chance = 0
    end
    if chance > 100 then
        chance = 100
    end
    return chance
end

local function resolveFollowPlayer(state)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local followOnlineId = state and state.followOnlineId or nil

    if players and players:size() > 0 then
        if followOnlineId ~= nil then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p and not p:isDead() and p.getOnlineID and p:getOnlineID() == followOnlineId then
                    return p
                end
            end
        end

        local closest = nil
        local closestDist = nil
        local cx = HTT.toNumber(state and state.centerX, 0)
        local cy = HTT.toNumber(state and state.centerY, 0)
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() then
                local dx = p:getX() - cx
                local dy = p:getY() - cy
                local distSq = dx * dx + dy * dy
                if closestDist == nil or distSq < closestDist then
                    closestDist = distSq
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
    runtime.nextCenterSyncHour = now + secondsToWorldHoursSafe(FOLLOW_SYNC_SECONDS, FOLLOW_SYNC_SECONDS)

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

local function appendVehicleNameCandidate(vehicle, out, accessorName)
    if not vehicle or not out then
        return
    end
    local accessor = vehicle[accessorName]
    if type(accessor) ~= "function" then
        return
    end
    local ok, value = pcall(accessor, vehicle)
    if not ok or value == nil then
        return
    end
    local text = string.lower(tostring(value))
    if text ~= "" then
        out[#out + 1] = text
    end
end

local function getVehicleNameCandidates(vehicle)
    local names = {}
    appendVehicleNameCandidate(vehicle, names, "getScriptName")
    appendVehicleNameCandidate(vehicle, names, "getDisplayName")
    appendVehicleNameCandidate(vehicle, names, "getVehicleType")

    if vehicle and vehicle.getScript then
        local okScript, script = pcall(function()
            return vehicle:getScript()
        end)
        if okScript and script then
            if script.getName then
                local okName, value = pcall(function()
                    return script:getName()
                end)
                if okName and value then
                    names[#names + 1] = string.lower(tostring(value))
                end
            end
            if script.getFullName then
                local okFull, value = pcall(function()
                    return script:getFullName()
                end)
                if okFull and value then
                    names[#names + 1] = string.lower(tostring(value))
                end
            end
        end
    end

    return names
end

local function isMilitaryVehicle(vehicle)
    if not vehicle then
        return false
    end

    local candidates = getVehicleNameCandidates(vehicle)
    for i = 1, #candidates do
        local text = candidates[i]
        if MILITARY_EXACT_SCRIPTS[text] then
            return true
        end
        for j = 1, #MILITARY_NAME_PATTERNS do
            local pattern = MILITARY_NAME_PATTERNS[j]
            if string.find(text, pattern, 1, true) then
                return true
            end
        end
    end

    return false
end

local function findNearestMilitaryVehicle(state)
    local cell = getCell and getCell() or nil
    if not cell or not cell.getVehicles then
        return nil
    end

    local vehicles = cell:getVehicles()
    if not vehicles then
        return nil
    end

    local cx = HTT.toNumber(state and state.centerX, 0)
    local cy = HTT.toNumber(state and state.centerY, 0)
    local cz = HTT.toNumber(state and state.centerZ, 0)
    local radius = math.max(10, HTT.toNumber(state and state.radius, 72))
    local radiusSq = radius * radius

    local bestVehicle = nil
    local bestDistSq = nil

    for i = 0, vehicles:size() - 1 do
        local vehicle = vehicles:get(i)
        if vehicle and isMilitaryVehicle(vehicle) then
            local vx = HTT.toNumber(vehicle:getX(), nil)
            local vy = HTT.toNumber(vehicle:getY(), nil)
            local vz = HTT.toNumber(vehicle:getZ(), cz)
            if vx ~= nil and vy ~= nil then
                local dz = math.abs(vz - cz)
                if dz <= 2 then
                    local dx = vx - cx
                    local dy = vy - cy
                    local distSq = dx * dx + dy * dy
                    if distSq <= radiusSq and (bestDistSq == nil or distSq < bestDistSq) then
                        bestDistSq = distSq
                        bestVehicle = vehicle
                    end
                end
            end
        end
    end

    return bestVehicle
end

local function damageVehiclePart(vehicle, partId, damageTankFuel)
    if not vehicle or not partId then
        return false
    end

    local part = vehicle.getPartById and vehicle:getPartById(partId) or nil
    if not part then
        return false
    end

    if part.setCondition then
        pcall(function()
            part:setCondition(0)
        end)
    end

    if damageTankFuel and part.setContainerContentAmount then
        pcall(function()
            part:setContainerContentAmount(0)
        end)
    end

    if vehicle.transmitPartCondition then
        pcall(function()
            vehicle:transmitPartCondition(part)
        end)
    end
    if vehicle.transmitPartModData then
        pcall(function()
            vehicle:transmitPartModData(part)
        end)
    end

    return true
end

local function emitStrikeExplosion(vehicle)
    if not vehicle then
        return false
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return false
    end

    local vx = math.floor(HTT.toNumber(vehicle:getX(), 0))
    local vy = math.floor(HTT.toNumber(vehicle:getY(), 0))
    local vz = math.floor(HTT.toNumber(vehicle:getZ(), 0))
    local sq = cell:getGridSquare(vx, vy, vz)
    if not sq then
        return false
    end

    local exploded = false
    if IsoFireManager and IsoFireManager.explode then
        local ok = pcall(function()
            IsoFireManager.explode(cell, sq, 100)
        end)
        exploded = exploded or ok
    end

    if IsoFireManager and IsoFireManager.StartFire then
        pcall(function()
            IsoFireManager.StartFire(cell, sq, true, 100, 500)
        end)
    end

    if IsoFireManager and IsoFireManager.StartSmoke then
        pcall(function()
            IsoFireManager.StartSmoke(cell, sq, true, 45, 180)
        end)
    end

    return exploded
end

local function broadcastApproachSound(state, eventDef)
    if not state or not eventDef or not eventDef.startSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 28,
        HTT.Config.DefaultSoundRadius + 18
    )
    HTT.Server.broadcastSound(
        eventDef.startSound,
        HTT.toNumber(state.centerX, 0),
        HTT.toNumber(state.centerY, 0),
        HTT.toNumber(state.centerZ, 0),
        soundRadius,
        {
            eventId = "military_vehicle_strike_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function broadcastStrikeSound(state, eventDef, vehicle)
    if not state or not eventDef or not eventDef.actionSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local x = HTT.toNumber(state.centerX, 0)
    local y = HTT.toNumber(state.centerY, 0)
    local z = HTT.toNumber(state.centerZ, 0)
    if vehicle then
        x = HTT.toNumber(vehicle:getX(), x)
        y = HTT.toNumber(vehicle:getY(), y)
        z = HTT.toNumber(vehicle:getZ(), z)
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 28,
        HTT.Config.DefaultSoundRadius + 18
    )
    HTT.Server.broadcastSound(
        eventDef.actionSound,
        x,
        y,
        z,
        soundRadius,
        {
            eventId = "military_vehicle_strike_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function resolveStrike(state, eventDef, now)
    runtime.strikeResolved = true
    runtime.finishHour = now + secondsToWorldHoursSafe(STRIKE_WINDOW_SECONDS, STRIKE_WINDOW_SECONDS)

    -- Always play activation/strike sound right after rotor phase ends.
    broadcastStrikeSound(state, eventDef, nil)

    local chance = getStrikeChancePercent()
    local roll = ZombRandFloat(0, 100)
    if roll > chance then
        HTT.log(string.format(
            "Military strike skipped by chance roll=%.2f chance=%.2f",
            roll,
            chance
        ))
        return
    end

    local vehicle = findNearestMilitaryVehicle(state)
    if not vehicle then
        HTT.log("Military strike aborted: no eligible military vehicle in range.")
        return
    end

    -- Strike now manifests as an explosive fire hit on the vehicle tile.
    local exploded = emitStrikeExplosion(vehicle)
    -- Keep minimal mechanical disable so the target doesn't keep driving through fire.
    local disabledEngine = damageVehiclePart(vehicle, "Engine", false)
    local emptiedTank = damageVehiclePart(vehicle, "GasTank", true)
    local scriptName = vehicle.getScriptName and tostring(vehicle:getScriptName() or "?") or "?"
    HTT.log(string.format(
        "Military strike resolved target=%s explosion=%s engineDisabled=%s tankEmptied=%s at=(%.1f, %.1f, %.1f)",
        tostring(scriptName),
        tostring(exploded),
        tostring(disabledEngine),
        tostring(emptiedTank),
        HTT.toNumber(vehicle:getX(), 0),
        HTT.toNumber(vehicle:getY(), 0),
        HTT.toNumber(vehicle:getZ(), 0)
    ))
end

local function militaryVehicleStrikeTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "military_vehicle_strike_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "actionHour", "finishHour", "nextCenterSyncHour" },
                now
            )
        end
        return
    end
    if now >= state.endHour then
        if HTT.Server and HTT.Server.stopEvent then
            HTT.Server.stopEvent("duration-expired")
        end
        resetRuntime()
        return
    end

    local eventDef = HTT.getEventDefinition("military_vehicle_strike_event")
    if not eventDef then
        return
    end

    local eventStart = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStart then
        runtime.eventStartHour = eventStart
        runtime.actionHour = eventStart + secondsToWorldHoursSafe(
            STRIKE_APPROACH_SECONDS,
            STRIKE_APPROACH_SECONDS
        )
        runtime.finishHour = 0
        runtime.strikeResolved = false
        runtime.nextCenterSyncHour = 0
        broadcastApproachSound(state, eventDef)
    end

    updateDynamicCenter(state, now)

    if not runtime.strikeResolved and now >= HTT.toNumber(runtime.actionHour, now) then
        resolveStrike(state, eventDef, now)
    end

    if runtime.strikeResolved and now >= HTT.toNumber(runtime.finishHour, now) then
        if HTT.Server and HTT.Server.stopEvent then
            HTT.Server.stopEvent("military-strike-complete")
        end
        resetRuntime()
    end
end

local strikeTickHooked = registerEvent("OnTick", militaryVehicleStrikeTick)
if not strikeTickHooked then
    registerEvent("EveryOneMinute", militaryVehicleStrikeTick)
end

registerEvent("OnGameStart", function()
    HTT.log(
        "Server military vehicle strike system loaded (hook="
            .. tostring(strikeTickHooked and "OnTick" or "EveryOneMinute")
            .. ")"
    )
end)
