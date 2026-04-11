require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerDownedHeli = HTT.ServerDownedHeli or {}

if HTT._serverDownedHeliLoaded then
    return
end
HTT._serverDownedHeliLoaded = true

local runtime = {
    eventStartHour = 0,
    phase = "idle",
    startSoundPlayed = false,
    collapseHour = 0,
    impactHour = 0,
    nextLureHour = 0,
    lurePulsesLeft = 0,
    crashX = 0,
    crashY = 0,
    crashZ = 0,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.phase = "idle"
    runtime.startSoundPlayed = false
    runtime.collapseHour = 0
    runtime.impactHour = 0
    runtime.nextLureHour = 0
    runtime.lurePulsesLeft = 0
    runtime.crashX = 0
    runtime.crashY = 0
    runtime.crashZ = 0
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

local function resolveReferencePlayer(state)
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

        local target = nil
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
                    target = p
                end
            end
        end

        return target
    end

    if getPlayer then
        local p = getPlayer()
        if p and not p:isDead() then
            return p
        end
    end

    return nil
end

local function pickCrashPoint(state, player)
    local minDist = HTT.toNumber(HTT.Config.DownedHeliMinDistanceFromPlayer, 45)
    local maxDist = HTT.toNumber(HTT.Config.DownedHeliMaxDistanceFromPlayer, 95)
    if minDist < 12 then
        minDist = 12
    end
    if maxDist < minDist then
        maxDist = minDist
    end

    local baseX = player and player:getX() or HTT.toNumber(state.centerX, 0)
    local baseY = player and player:getY() or HTT.toNumber(state.centerY, 0)
    local baseZ = player and player:getZ() or HTT.toNumber(state.centerZ, 0)

    local attemptX = baseX
    local attemptY = baseY
    local minDistSq = minDist * minDist
    for _ = 1, 12 do
        local angle = ZombRandFloat(0, math.pi * 2)
        local distance = ZombRandFloat(minDist, maxDist)
        attemptX = baseX + math.cos(angle) * distance
        attemptY = baseY + math.sin(angle) * distance
        local dx = attemptX - baseX
        local dy = attemptY - baseY
        if (dx * dx + dy * dy) >= minDistSq then
            break
        end
    end

    return attemptX, attemptY, baseZ
end

local function getCrashSoundRadius(state)
    local configured = HTT.toNumber(HTT.Config.DownedHeliSoundRadius, 170)
    if configured > 0 then
        return configured
    end

    local base = HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius)
    return math.max(base + 50, HTT.Config.DefaultSoundRadius + 35)
end

local function broadcastCrashSound(state, soundName, x, y, z)
    if not soundName or soundName == "" then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local extraArgs = nil
    local eventDef = HTT.getEventDefinition and HTT.getEventDefinition(state and state.eventId or "downed_heli") or nil
    if eventDef and (
        soundName == tostring(eventDef.startSound or "")
        or soundName == tostring(eventDef.collapseSound or "")
    ) then
        extraArgs = {
            eventId = state and state.eventId or "downed_heli",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    end

    HTT.Server.broadcastSound(
        soundName,
        HTT.toNumber(x, state.centerX),
        HTT.toNumber(y, state.centerY),
        HTT.toNumber(z, state.centerZ),
        getCrashSoundRadius(state),
        extraArgs
    )
end

local function emitCrashAttractSound(x, y, z, state)
    if not addSound then
        return
    end

    local attractRadius = math.floor(HTT.toNumber(HTT.Config.DownedHeliAttractRadius, 150))
    if attractRadius < 20 then
        attractRadius = 20
    end

    local attractVolume = math.floor(HTT.toNumber(HTT.Config.DownedHeliAttractVolume, 150))
    if attractVolume < 10 then
        attractVolume = 10
    end

    addSound(
        nil,
        math.floor(HTT.toNumber(x, state.centerX)),
        math.floor(HTT.toNumber(y, state.centerY)),
        math.floor(HTT.toNumber(z, state.centerZ)),
        attractRadius,
        attractVolume
    )
end

local function syncCrashCenterToState(state, x, y, z)
    state.centerX = HTT.toNumber(x, state.centerX)
    state.centerY = HTT.toNumber(y, state.centerY)
    state.centerZ = HTT.toNumber(z, state.centerZ)

    if HTT.Server and HTT.Server.broadcastEventState then
        HTT.Server.broadcastEventState()
    end
end

local function initRuntimeIfNeeded(state, now, eventDef)
    if runtime.eventStartHour == HTT.toNumber(state.startHour, 0) then
        return
    end

    runtime.eventStartHour = HTT.toNumber(state.startHour, now)
    runtime.phase = "approach"
    runtime.startSoundPlayed = false
    runtime.nextLureHour = 0
    runtime.impactHour = 0

    local pulses = math.floor(HTT.toNumber(HTT.Config.DownedHeliAttractPulseCount, 5))
    if pulses < 1 then
        pulses = 1
    end
    runtime.lurePulsesLeft = pulses

    local rotorToCollapseSec = HTT.toNumber(HTT.Config.DownedHeliRotorToCollapseSeconds, nil)
    if rotorToCollapseSec == nil then
        rotorToCollapseSec = HTT.toNumber(HTT.Config.DownedHeliApproachMinutes, 0.20) * 60
    end
    if rotorToCollapseSec < 0 then
        rotorToCollapseSec = 0
    end
    if eventDef and tostring(eventDef.collapseSound or "") == "" and rotorToCollapseSec > 8.0 then
        rotorToCollapseSec = 8.0
    end
    runtime.collapseHour = now + HTT.secondsToWorldHours(rotorToCollapseSec, 45.0)

    local referencePlayer = resolveReferencePlayer(state)
    runtime.crashX, runtime.crashY, runtime.crashZ = pickCrashPoint(state, referencePlayer)
    syncCrashCenterToState(state, runtime.crashX, runtime.crashY, runtime.crashZ)

    HTT.log(string.format(
        "Downed heli target selected at (%.1f, %.1f, %.1f) pulses=%d",
        runtime.crashX,
        runtime.crashY,
        runtime.crashZ,
        runtime.lurePulsesLeft
    ))
end

local function playApproachStartIfNeeded(state, eventDef)
    if runtime.startSoundPlayed then
        return
    end

    runtime.startSoundPlayed = true
    local startSound = (eventDef and eventDef.startSound) or "HTT_heli_loop_far"
    broadcastCrashSound(state, startSound, runtime.crashX, runtime.crashY, runtime.crashZ)
end

local function finishEvent()
    if HTT.Server and HTT.Server.stopEvent then
        HTT.Server.stopEvent("downed-heli-complete")
    end
end

local function scheduleNextPulse(now)
    local intervalMinutes = HTT.toNumber(HTT.Config.DownedHeliAttractPulseIntervalMinutes, 0.20)
    if intervalMinutes < 0.05 then
        intervalMinutes = 0.05
    end
    runtime.nextLureHour = now + (intervalMinutes / 60)
end

local function onCollapse(state, eventDef, now)
    runtime.phase = "collapse_wait"

    local collapseSound = (eventDef and eventDef.collapseSound)
        or (eventDef and eventDef.endSound)
        or "HTT_structure_collapse_far"
    local hasCollapseSound = collapseSound ~= nil and tostring(collapseSound) ~= ""
    if hasCollapseSound then
        broadcastCrashSound(state, collapseSound, runtime.crashX, runtime.crashY, runtime.crashZ)
    end

    local collapseToImpactSec = HTT.toNumber(HTT.Config.DownedHeliCollapseToImpactSeconds, 10.0)
    if collapseToImpactSec < 0 then
        collapseToImpactSec = 0
    end
    if not hasCollapseSound and collapseToImpactSec > 1.2 then
        collapseToImpactSec = 1.2
    end
    runtime.impactHour = now + HTT.secondsToWorldHours(collapseToImpactSec, 10.0)
end

local function onImpact(state, eventDef, now)
    runtime.phase = "lure"

    local impactSound = (eventDef and eventDef.impactSound)
        or (eventDef and eventDef.hitSound)
        or "HTT_explosion_impact"
    broadcastCrashSound(state, impactSound, runtime.crashX, runtime.crashY, runtime.crashZ)
    emitCrashAttractSound(runtime.crashX, runtime.crashY, runtime.crashZ, state)

    runtime.lurePulsesLeft = runtime.lurePulsesLeft - 1
    if runtime.lurePulsesLeft <= 0 then
        finishEvent()
        return
    end

    scheduleNextPulse(now)
end

local function onLurePulse(state, now)
    emitCrashAttractSound(runtime.crashX, runtime.crashY, runtime.crashZ, state)
    runtime.lurePulsesLeft = runtime.lurePulsesLeft - 1

    if runtime.lurePulsesLeft <= 0 then
        finishEvent()
        return
    end

    scheduleNextPulse(now)
end

local function downedHeliTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "downed_heli" then
        resetRuntime()
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "collapseHour", "impactHour", "nextLureHour" },
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

    local eventDef = HTT.getEventDefinition("downed_heli")
    if not eventDef then
        return
    end

    initRuntimeIfNeeded(state, now, eventDef)
    playApproachStartIfNeeded(state, eventDef)

    if runtime.phase == "approach" and now >= HTT.toNumber(runtime.collapseHour, 0) then
        onCollapse(state, eventDef, now)
        return
    end

    if runtime.phase == "collapse_wait" and now >= HTT.toNumber(runtime.impactHour, 0) then
        onImpact(state, eventDef, now)
        return
    end

    if runtime.phase == "lure" and now >= HTT.toNumber(runtime.nextLureHour, 0) then
        onLurePulse(state, now)
    end
end

local crashTickHooked = registerEvent("OnTick", downedHeliTick)
if not crashTickHooked then
    registerEvent("EveryOneMinute", downedHeliTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server downed-heli system loaded (hook=" .. tostring(crashTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
