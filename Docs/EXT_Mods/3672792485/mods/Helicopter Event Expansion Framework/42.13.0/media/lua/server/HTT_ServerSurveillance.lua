require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerSurveillance = HTT.ServerSurveillance or {}

if HTT._serverSurveillanceLoaded then
    return
end
HTT._serverSurveillanceLoaded = true

local SURVEILLANCE_APPROACH_SECONDS = 30.0
local SURVEILLANCE_EFFECT_INTERVAL_SECONDS = 4.0
local SURVEILLANCE_PANIC_GAIN_PER_MIN = 0.35
local SURVEILLANCE_STRESS_GAIN_PER_MIN = 0.0075
local SURVEILLANCE_APPLY_PLAYER_PRESSURE = true
local SURVEILLANCE_MARK_HOURS = 6.0
local SURVEILLANCE_MARK_KEY = "HTT_SurveillanceMarkedUntil"
local FOLLOW_SYNC_SECONDS = 2.5

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    actionStarted = false,
    nextEffectHour = 0,
    lastEffectHour = 0,
    nextCenterSyncHour = 0,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.actionStarted = false
    runtime.nextEffectHour = 0
    runtime.lastEffectHour = 0
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

local function getPlayerModDataSafe(player)
    if not player or not player.getModData then
        return nil
    end

    local ok, md = pcall(function()
        return player:getModData()
    end)
    if not ok then
        return nil
    end
    return md
end

local function setSurveillanceMark(player, now)
    local md = getPlayerModDataSafe(player)
    if not md then
        return
    end

    md[SURVEILLANCE_MARK_KEY] = HTT.toNumber(now, 0) + SURVEILLANCE_MARK_HOURS
end

local function addStat(stats, statName, amount, maxValue)
    if not stats then
        return
    end

    local gain = HTT.toNumber(amount, 0)
    if gain <= 0 then
        return
    end

    if statName == "PANIC" then
        if CharacterStat and CharacterStat.PANIC and stats.add then
            stats:add(CharacterStat.PANIC, gain)
            return
        end
        if stats.getPanic and stats.setPanic then
            local current = HTT.toNumber(stats:getPanic(), 0)
            stats:setPanic(math.min(maxValue, current + gain))
        end
        return
    end

    if statName == "STRESS" then
        if CharacterStat and CharacterStat.STRESS and stats.add then
            stats:add(CharacterStat.STRESS, gain)
            return
        end
        if stats.getStress and stats.setStress then
            local current = HTT.toNumber(stats:getStress(), 0)
            stats:setStress(math.min(maxValue, current + gain))
        end
    end
end

local function applySurveillancePressure(player, tickMinutes)
    if not SURVEILLANCE_APPLY_PLAYER_PRESSURE then
        return
    end

    if not player or player:isDead() then
        return
    end

    local stats = nil
    if player.getStats then
        local ok, result = pcall(function()
            return player:getStats()
        end)
        if ok then
            stats = result
        end
    end
    if not stats then
        return
    end

    local minutes = HTT.toNumber(tickMinutes, 0)
    if minutes <= 0 then
        return
    end

    local panicGain = SURVEILLANCE_PANIC_GAIN_PER_MIN * minutes
    local stressGain = SURVEILLANCE_STRESS_GAIN_PER_MIN * minutes

    addStat(stats, "PANIC", panicGain, 100)
    addStat(stats, "STRESS", stressGain, 1)
end

local function collectTargetsInRadius(state, radius)
    local targets = {}
    local seen = {}
    local limit = radius * radius
    local cx = HTT.toNumber(state and state.centerX, 0)
    local cy = HTT.toNumber(state and state.centerY, 0)
    local cz = HTT.toNumber(state and state.centerZ, 0)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local wantedId = state and state.followOnlineId or nil

    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() then
                local dx = p:getX() - cx
                local dy = p:getY() - cy
                local dz = math.abs(HTT.toNumber(p:getZ(), cz) - cz)
                local inRadius = (dx * dx + dy * dy) <= limit and dz <= 2
                local isFollowTarget = wantedId ~= nil and p.getOnlineID and p:getOnlineID() == wantedId
                if inRadius or isFollowTarget then
                    targets[#targets + 1] = p
                    seen[p] = true
                end
            end
        end

        if #targets <= 0 then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p and not p:isDead() and not seen[p] then
                    targets[#targets + 1] = p
                    break
                end
            end
        end
    end

    if #targets <= 0 and getPlayer then
        local p = getPlayer()
        if p and not p:isDead() then
            targets[#targets + 1] = p
        end
    end

    return targets
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

local function broadcastApproachSound(state, eventDef)
    if not eventDef or not eventDef.startSound then
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
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "surveillance_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function broadcastActionSound(state, eventDef)
    if not eventDef or not eventDef.actionSound then
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
        eventDef.actionSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "surveillance_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function applyEffectPulse(state, now)
    if runtime.nextEffectHour > 0 and now < runtime.nextEffectHour then
        return
    end

    local previousHour = HTT.toNumber(runtime.lastEffectHour, now)
    local tickMinutes = (now - previousHour) * 60.0
    if tickMinutes <= 0 then
        tickMinutes = SURVEILLANCE_EFFECT_INTERVAL_SECONDS / 60.0
    end

    local radius = HTT.toNumber(state.radius, 36)
    if radius < 8 then
        radius = 8
    end
    local targets = collectTargetsInRadius(state, radius)
    for i = 1, #targets do
        local player = targets[i]
        applySurveillancePressure(player, tickMinutes)
        setSurveillanceMark(player, now)
    end

    runtime.lastEffectHour = now
    runtime.nextEffectHour = now + secondsToWorldHoursSafe(
        SURVEILLANCE_EFFECT_INTERVAL_SECONDS,
        SURVEILLANCE_EFFECT_INTERVAL_SECONDS
    )
end

local function surveillanceTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "surveillance_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "actionHour", "nextEffectHour", "lastEffectHour", "nextCenterSyncHour" },
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

    local eventDef = HTT.getEventDefinition("surveillance_event")
    if not eventDef then
        return
    end

    local eventStartHour = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStartHour then
        runtime.eventStartHour = eventStartHour
        runtime.actionHour = eventStartHour + secondsToWorldHoursSafe(
            SURVEILLANCE_APPROACH_SECONDS,
            SURVEILLANCE_APPROACH_SECONDS
        )
        runtime.actionStarted = false
        runtime.nextEffectHour = 0
        runtime.lastEffectHour = eventStartHour
        runtime.nextCenterSyncHour = 0
        broadcastApproachSound(state, eventDef)
    end

    updateDynamicCenter(state, now)

    if not runtime.actionStarted and now >= HTT.toNumber(runtime.actionHour, now) then
        runtime.actionStarted = true
        runtime.lastEffectHour = now
        runtime.nextEffectHour = now
        broadcastActionSound(state, eventDef)
    end

    if runtime.actionStarted then
        applyEffectPulse(state, now)
    end
end

local surveillanceTickHooked = registerEvent("OnTick", surveillanceTick)
if not surveillanceTickHooked then
    registerEvent("EveryOneMinute", surveillanceTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server surveillance system loaded (hook=" .. tostring(surveillanceTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
