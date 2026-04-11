require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerFuelReclamation = HTT.ServerFuelReclamation or {}

if HTT._serverFuelReclamationLoaded then
    return
end
HTT._serverFuelReclamationLoaded = true

local FUEL_APPROACH_SECONDS = 30.0
local FUEL_EXTRACTION_WINDOW_SECONDS = 10.0

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    finishHour = 0,
    actionApplied = false,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.finishHour = 0
    runtime.actionApplied = false
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

local function getDrainPercent()
    local pct = HTT.toNumber(HTT.Config and HTT.Config.FuelReclamationDrainPercent, 10)
    if pct == nil then
        return 10
    end
    if pct <= 1 then
        pct = pct * 100
    end
    if pct < 0 then
        pct = 0
    end
    if pct > 100 then
        pct = 100
    end
    return pct
end

local function getPumpFuelAmount(pump)
    if not pump then
        return nil, nil
    end

    if pump.getPipedFuelAmount then
        local ok, value = pcall(function()
            return pump:getPipedFuelAmount()
        end)
        if ok then
            return HTT.toNumber(value, nil), "piped"
        end
    end

    if pump.getModData then
        local okMd, md = pcall(function()
            return pump:getModData()
        end)
        if okMd and type(md) == "table" then
            local candidates = { "fuelAmount", "FuelAmount", "gasAmount", "GasAmount", "fuel", "gas" }
            for i = 1, #candidates do
                local key = candidates[i]
                local value = HTT.toNumber(md[key], nil)
                if value ~= nil then
                    return value, key
                end
            end
        end
    end

    return nil, nil
end

local function setPumpFuelAmount(pump, amount, sourceKey)
    local target = math.max(0, HTT.toNumber(amount, 0))
    if not pump then
        return false
    end

    if sourceKey == "piped" and pump.setPipedFuelAmount then
        local ok = pcall(function()
            pump:setPipedFuelAmount(target)
        end)
        if ok then
            return true
        end
    end

    if pump.getModData then
        local okMd, md = pcall(function()
            return pump:getModData()
        end)
        if okMd and type(md) == "table" then
            local key = sourceKey
            if key == nil or key == "piped" then
                key = "fuelAmount"
            end
            md[key] = target
            if pump.transmitModData then
                pcall(function()
                    pump:transmitModData()
                end)
            end
            return true
        end
    end

    return false
end

local function collectLoadedGasPumps()
    local pumps = {}
    local seen = {}
    local cell = getCell and getCell() or nil
    if not cell or not cell.getObjectList then
        return pumps
    end

    local objectList = cell:getObjectList()
    if not objectList then
        return pumps
    end

    for i = 0, objectList:size() - 1 do
        local obj = objectList:get(i)
        if obj and not seen[obj] then
            local amount, sourceKey = getPumpFuelAmount(obj)
            if amount ~= nil and amount > 0 and sourceKey ~= nil then
                pumps[#pumps + 1] = { pump = obj, amount = amount, sourceKey = sourceKey }
                seen[obj] = true
            end
        end
    end

    return pumps
end

local function applyFuelDrain()
    local drainPercent = getDrainPercent()
    local drainFactor = drainPercent / 100.0
    local pumps = collectLoadedGasPumps()

    local scanned = 0
    local affected = 0
    local totalDrained = 0

    for i = 1, #pumps do
        local entry = pumps[i]
        local current = math.max(0, HTT.toNumber(entry.amount, 0))
        scanned = scanned + 1

        if current > 0 and drainFactor > 0 then
            local drainUnits = math.floor((current * drainFactor) + 0.5)
            if drainUnits <= 0 then
                drainUnits = 1
            end
            if drainUnits > current then
                drainUnits = current
            end

            local newAmount = current - drainUnits
            if setPumpFuelAmount(entry.pump, newAmount, entry.sourceKey) then
                affected = affected + 1
                totalDrained = totalDrained + drainUnits
            end
        end
    end

    return scanned, affected, totalDrained, drainPercent
end

local function broadcastApproachSound(state, eventDef)
    if not state or not eventDef or not eventDef.startSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 24,
        HTT.Config.DefaultSoundRadius + 16
    )

    HTT.Server.broadcastSound(
        eventDef.startSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "fuel_reclamation_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function broadcastActionSound(state, eventDef)
    if not state or not eventDef or not eventDef.actionSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 24,
        HTT.Config.DefaultSoundRadius + 16
    )

    HTT.Server.broadcastSound(
        eventDef.actionSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "fuel_reclamation_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function fuelReclamationTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "fuel_reclamation_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(runtime, { "actionHour", "finishHour" }, now)
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

    local eventDef = HTT.getEventDefinition("fuel_reclamation_event")
    if not eventDef then
        return
    end

    local eventStart = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStart then
        runtime.eventStartHour = eventStart
        runtime.actionHour = eventStart + secondsToWorldHoursSafe(
            FUEL_APPROACH_SECONDS,
            FUEL_APPROACH_SECONDS
        )
        runtime.finishHour = runtime.actionHour + secondsToWorldHoursSafe(
            FUEL_EXTRACTION_WINDOW_SECONDS,
            FUEL_EXTRACTION_WINDOW_SECONDS
        )
        runtime.actionApplied = false
        broadcastApproachSound(state, eventDef)
    end

    if not runtime.actionApplied and now >= HTT.toNumber(runtime.actionHour, now) then
        runtime.actionApplied = true
        broadcastActionSound(state, eventDef)

        local scanned, affected, totalDrained, percent = applyFuelDrain()
        HTT.log(string.format(
            "Fuel reclamation executed drain=%.0f%% scanned=%d affected=%d drained=%.0f",
            percent,
            scanned,
            affected,
            totalDrained
        ))
    end

    if runtime.actionApplied and now >= HTT.toNumber(runtime.finishHour, now) then
        if HTT.Server and HTT.Server.stopEvent then
            HTT.Server.stopEvent("fuel-reclamation-complete")
        end
        resetRuntime()
    end
end

local fuelTickHooked = registerEvent("OnTick", fuelReclamationTick)
if not fuelTickHooked then
    registerEvent("EveryOneMinute", fuelReclamationTick)
end

registerEvent("OnGameStart", function()
    HTT.log(
        "Server fuel reclamation system loaded (hook="
            .. tostring(fuelTickHooked and "OnTick" or "EveryOneMinute")
            .. ")"
    )
end)
