require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerPropagandaBroadcast = HTT.ServerPropagandaBroadcast or {}

if HTT._serverPropagandaBroadcastLoaded then
    return
end
HTT._serverPropagandaBroadcastLoaded = true

local PROPAGANDA_APPROACH_SECONDS = 30.0
local PROPAGANDA_ANNOUNCE_INTERVAL_SECONDS = 30.0
local PROPAGANDA_ROTOR_REPEAT_SECONDS = 30.0
local PROPAGANDA_FOLLOW_SYNC_SECONDS = 1.5
local PROPAGANDA_ATTRACT_RADIUS = 180
local PROPAGANDA_ATTRACT_VOLUME = 150
local PROPAGANDA_EFFECT_RADIUS = 60
local PROPAGANDA_STRESS_GAIN = 0.13

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    nextBroadcastHour = 0,
    nextRotorHour = 0,
    nextCenterSyncHour = 0,
    announceIndex = 0,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.nextBroadcastHour = 0
    runtime.nextRotorHour = 0
    runtime.nextCenterSyncHour = 0
    runtime.announceIndex = 0
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
        PROPAGANDA_FOLLOW_SYNC_SECONDS,
        PROPAGANDA_FOLLOW_SYNC_SECONDS
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

local function broadcastSound(state, soundName, radius, x, y, z, extraArgs)
    if not soundName or soundName == "" then
        return false
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return false
    end

    local soundRadius = math.max(
        HTT.toNumber(radius, HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius)),
        HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius)
    )

    local args = {
        eventId = "propaganda_broadcast_event",
        attachToFollowPlayer = true,
        followOnlineId = state and state.followOnlineId or nil,
    }
    if type(extraArgs) == "table" then
        for k, v in pairs(extraArgs) do
            args[k] = v
        end
    end

    return HTT.Server.broadcastSound(
        soundName,
        HTT.toNumber(x, state.centerX),
        HTT.toNumber(y, state.centerY),
        HTT.toNumber(z, state.centerZ),
        soundRadius,
        args
    )
end

local function emitAttractSound(state)
    if not addSound then
        return
    end

    addSound(
        nil,
        math.floor(HTT.toNumber(state.centerX, 0)),
        math.floor(HTT.toNumber(state.centerY, 0)),
        math.floor(HTT.toNumber(state.centerZ, 0)),
        PROPAGANDA_ATTRACT_RADIUS,
        PROPAGANDA_ATTRACT_VOLUME
    )
end

local function addStress(player, amount)
    if not player or player:isDead() or not player.getStats then
        return
    end

    local stats = player:getStats()
    if not stats then
        return
    end

    local gain = math.max(0, HTT.toNumber(amount, 0))
    if gain <= 0 then
        return
    end

    if CharacterStat and CharacterStat.STRESS and stats.add then
        stats:add(CharacterStat.STRESS, gain)
        return
    end

    if stats.getStress and stats.setStress then
        local current = HTT.toNumber(stats:getStress(), 0)
        stats:setStress(math.min(1, current + gain))
    end
end

local function applyBroadcastPressure(state)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local effectRadiusSq = PROPAGANDA_EFFECT_RADIUS * PROPAGANDA_EFFECT_RADIUS
    local cx = HTT.toNumber(state.centerX, 0)
    local cy = HTT.toNumber(state.centerY, 0)
    local cz = HTT.toNumber(state.centerZ, 0)

    local applied = 0
    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() then
                local dx = p:getX() - cx
                local dy = p:getY() - cy
                local dz = math.abs(HTT.toNumber(p:getZ(), cz) - cz)
                if dz <= 2 and (dx * dx + dy * dy) <= effectRadiusSq then
                    addStress(p, PROPAGANDA_STRESS_GAIN)
                    applied = applied + 1
                end
            end
        end
    elseif getPlayer then
        local p = getPlayer()
        if p and not p:isDead() then
            addStress(p, PROPAGANDA_STRESS_GAIN)
            applied = 1
        end
    end

    return applied
end

local function playRotorLoopIfNeeded(state, eventDef, now)
    local nextRotor = HTT.toNumber(runtime.nextRotorHour, 0)
    if nextRotor > 0 and now < nextRotor then
        return
    end

    runtime.nextRotorHour = now + secondsToWorldHoursSafe(
        PROPAGANDA_ROTOR_REPEAT_SECONDS,
        PROPAGANDA_ROTOR_REPEAT_SECONDS
    )

    local rotorSound = eventDef and eventDef.startSound or "HTT_loop_medium_broadcasting_rotor"
    local radius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 24,
        HTT.Config.DefaultSoundRadius + 16
    )
    broadcastSound(state, rotorSound, radius)
end

local function getBroadcastSound(eventDef, index)
    local odd = (index % 2) == 1
    if odd then
        return eventDef and eventDef.voiceSound or "HTT_distorted_public_announcement_01"
    end
    return eventDef and eventDef.fireSound or "HTT_distorted_public_announcement_02"
end

local function runBroadcastPulse(state, eventDef, now)
    runtime.announceIndex = runtime.announceIndex + 1
    local soundName = getBroadcastSound(eventDef, runtime.announceIndex)
    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 26,
        HTT.Config.DefaultSoundRadius + 20
    )
    broadcastSound(state, soundName, soundRadius)

    emitAttractSound(state)
    local pressuredPlayers = applyBroadcastPressure(state)

    runtime.nextBroadcastHour = now + secondsToWorldHoursSafe(
        PROPAGANDA_ANNOUNCE_INTERVAL_SECONDS,
        PROPAGANDA_ANNOUNCE_INTERVAL_SECONDS
    )

    HTT.log(string.format(
        "Propaganda pulse index=%d pressuredPlayers=%d center=(%.1f, %.1f, %.1f)",
        runtime.announceIndex,
        pressuredPlayers,
        HTT.toNumber(state.centerX, 0),
        HTT.toNumber(state.centerY, 0),
        HTT.toNumber(state.centerZ, 0)
    ))
end

local function propagandaTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "propaganda_broadcast_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "actionHour", "nextBroadcastHour", "nextRotorHour", "nextCenterSyncHour" },
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

    local eventDef = HTT.getEventDefinition("propaganda_broadcast_event")
    if not eventDef then
        return
    end

    local eventStart = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStart then
        runtime.eventStartHour = eventStart
        runtime.actionHour = eventStart + secondsToWorldHoursSafe(
            PROPAGANDA_APPROACH_SECONDS,
            PROPAGANDA_APPROACH_SECONDS
        )
        runtime.nextBroadcastHour = runtime.actionHour
        runtime.nextRotorHour = eventStart + secondsToWorldHoursSafe(
            PROPAGANDA_ROTOR_REPEAT_SECONDS,
            PROPAGANDA_ROTOR_REPEAT_SECONDS
        )
        runtime.nextCenterSyncHour = 0
        runtime.announceIndex = 0
    end

    updateDynamicCenter(state, now)
    playRotorLoopIfNeeded(state, eventDef, now)

    if now < HTT.toNumber(runtime.actionHour, now) then
        return
    end

    if now >= HTT.toNumber(runtime.nextBroadcastHour, now) then
        runBroadcastPulse(state, eventDef, now)
    end
end

local propagandaTickHooked = registerEvent("OnTick", propagandaTick)
if not propagandaTickHooked then
    registerEvent("EveryOneMinute", propagandaTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server propaganda broadcast system loaded (hook=" .. tostring(propagandaTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
