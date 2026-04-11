require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerSmokeCurtain = HTT.ServerSmokeCurtain or {}

if HTT._serverSmokeCurtainLoaded then
    return
end
HTT._serverSmokeCurtainLoaded = true

local SMOKE_APPROACH_SECONDS = 30.0
local FOLLOW_SYNC_SECONDS = 1.5
local STEALTH_PULSE_SECONDS = 0.05

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    actionSoundPlayed = false,
    nextCenterSyncHour = 0,
    nextStealthPulseHour = 0,
    concealedZombies = {},
}

local function setZombieUselessSafe(zombie, enabled)
    if not zombie or not zombie.setUseless or not zombie.isUseless then
        return false, false
    end

    local okState, current = pcall(zombie.isUseless, zombie)
    if not okState then
        return false, false
    end

    local desired = enabled == true
    if current == desired then
        return true, false
    end

    local okSet = pcall(zombie.setUseless, zombie, desired)
    return okSet, okSet
end

local function clearConcealedZombieFlags(activeConcealed)
    local concealed = runtime.concealedZombies
    if not concealed then
        return
    end

    for z, _ in pairs(concealed) do
        if not activeConcealed or not activeConcealed[z] then
            setZombieUselessSafe(z, false)
            concealed[z] = nil
        end
    end
end

local function resetRuntime()
    clearConcealedZombieFlags(nil)
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.actionSoundPlayed = false
    runtime.nextCenterSyncHour = 0
    runtime.nextStealthPulseHour = 0
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

local function collectSneakingPlayers(state)
    local sneaking = {}
    local seen = {}
    local wantedId = state and state.followOnlineId or nil
    local players = getOnlinePlayers and getOnlinePlayers() or nil

    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() and p.isSneaking and p:isSneaking() then
                sneaking[#sneaking + 1] = p
                seen[p] = true
            end
        end

        if #sneaking <= 0 and wantedId ~= nil then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p
                    and not p:isDead()
                    and p.getOnlineID
                    and p:getOnlineID() == wantedId
                    and p.isSneaking
                    and p:isSneaking()
                then
                    sneaking[#sneaking + 1] = p
                    seen[p] = true
                    break
                end
            end
        end
    end

    if #sneaking <= 0 and getPlayer then
        local p = getPlayer()
        if p and not p:isDead() and p.isSneaking and p:isSneaking() and not seen[p] then
            sneaking[#sneaking + 1] = p
        end
    end

    return sneaking
end

local function clearZombieTrackingForPlayer(zombie, player)
    if not zombie or not player then
        return false
    end

    local changed = false

    if zombie.getTarget and zombie.setTarget then
        local target = zombie:getTarget()
        if target == player then
            pcall(function()
                zombie:setTarget(nil)
            end)
            changed = true
        end
    end

    if zombie.setTargetSeenTime then
        pcall(function()
            zombie:setTargetSeenTime(0.0)
        end)
    end

    if zombie.clearAggroList then
        pcall(function()
            zombie:clearAggroList()
        end)
    end

    if zombie.setLastHeardSound then
        pcall(function()
            zombie:setLastHeardSound(-1, -1, -1)
        end)
    end

    if zombie.setPath2 then
        pcall(function()
            zombie:setPath2(nil)
        end)
    end

    -- Avoid direct field writes on Java userdata (Build 42 can throw "attempted index of non-table").
    -- We rely on safe API calls above for de-aggro.

    return changed
end

local function applySneakImperceptibility(state, now)
    if runtime.nextStealthPulseHour > 0 and now < runtime.nextStealthPulseHour then
        return
    end
    runtime.nextStealthPulseHour = now + secondsToWorldHoursSafe(STEALTH_PULSE_SECONDS, STEALTH_PULSE_SECONDS)

    local sneakingPlayers = collectSneakingPlayers(state)
    if #sneakingPlayers <= 0 then
        clearConcealedZombieFlags(nil)
        return
    end

    local cell = getCell and getCell() or nil
    if not cell then
        clearConcealedZombieFlags(nil)
        return
    end

    local zombies = cell:getZombieList()
    if not zombies or zombies:size() <= 0 then
        clearConcealedZombieFlags(nil)
        return
    end

    local concealRadius = math.max(HTT.toNumber(state and state.radius, 54), 54)
    local concealRadiusSq = concealRadius * concealRadius
    local activeConcealed = {}

    for i = zombies:size() - 1, 0, -1 do
        local z = zombies:get(i)
        if z and not z:isDead() then
            for pIndex = 1, #sneakingPlayers do
                local p = sneakingPlayers[pIndex]
                local shouldClear = false
                if z.getTarget and z:getTarget() == p then
                    shouldClear = true
                else
                    local dx = z:getX() - p:getX()
                    local dy = z:getY() - p:getY()
                    local dz = math.abs(HTT.toNumber(z:getZ(), 0) - HTT.toNumber(p:getZ(), 0))
                    shouldClear = dz <= 2 and ((dx * dx + dy * dy) <= concealRadiusSq)
                end

                if shouldClear then
                    clearZombieTrackingForPlayer(z, p)
                    local _, changed = setZombieUselessSafe(z, true)
                    if changed then
                        runtime.concealedZombies[z] = true
                    end
                    if runtime.concealedZombies[z] then
                        activeConcealed[z] = true
                    end
                    break
                end
            end
        end
    end

    clearConcealedZombieFlags(activeConcealed)
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
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 32,
        HTT.Config.DefaultSoundRadius + 22
    )
    HTT.Server.broadcastSound(
        eventDef.startSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "smoke_curtain_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function playSmokeActionSound(state, eventDef)
    if not eventDef or not eventDef.actionSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 32,
        HTT.Config.DefaultSoundRadius + 22
    )
    HTT.Server.broadcastSound(
        eventDef.actionSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "smoke_curtain_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function smokeCurtainTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "smoke_curtain_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "actionHour", "nextCenterSyncHour", "nextStealthPulseHour" },
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

    local eventDef = HTT.getEventDefinition("smoke_curtain_event")
    if not eventDef then
        return
    end

    local eventStartHour = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStartHour then
        runtime.eventStartHour = eventStartHour
        runtime.actionHour = eventStartHour + secondsToWorldHoursSafe(
            SMOKE_APPROACH_SECONDS,
            SMOKE_APPROACH_SECONDS
        )
        runtime.actionSoundPlayed = false
        runtime.nextCenterSyncHour = 0
        runtime.nextStealthPulseHour = 0
        broadcastApproachSound(state, eventDef)
    end

    updateDynamicCenter(state, now)
    applySneakImperceptibility(state, now)

    if now < HTT.toNumber(runtime.actionHour, now) then
        return
    end

    if not runtime.actionSoundPlayed then
        playSmokeActionSound(state, eventDef)
        runtime.actionSoundPlayed = true
    end
end

local smokeTickHooked = registerEvent("OnTick", smokeCurtainTick)
if not smokeTickHooked then
    registerEvent("EveryOneMinute", smokeCurtainTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server smoke curtain system loaded (hook=" .. tostring(smokeTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
