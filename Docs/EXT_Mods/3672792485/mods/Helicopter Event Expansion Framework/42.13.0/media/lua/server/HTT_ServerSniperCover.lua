require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerSniperCover = HTT.ServerSniperCover or {}

if HTT._serverSniperCoverLoaded then
    return
end
HTT._serverSniperCoverLoaded = true

local SNIPER_APPROACH_SECONDS = 30.0
local SNIPER_ROTOR_REPEAT_SECONDS = 30.0
local SNIPER_SHOT_MIN_SECONDS = 8.0
local SNIPER_SHOT_MAX_SECONDS = 16.0
local SNIPER_HIT_SOUND_DELAY_MIN_SECONDS = 0.80
local SNIPER_HIT_SOUND_DELAY_MAX_SECONDS = 1.35
local SNIPER_HIT_PITCH_VARIATION = 0.03
local SNIPER_HIT_VOLUME_VARIATION = 0.05
local SNIPER_RETRY_NO_TARGET_SECONDS = 2.0
local SNIPER_FOLLOW_SYNC_SECONDS = 1.5
local SNIPER_TARGET_RADIUS = 26
local SNIPER_PRIORITY_CLOSE_RADIUS = 10
local SNIPER_SHOT_SOUND_RADIUS = 48
local SNIPER_HIT_SOUND_RADIUS = 34
local SNIPER_HIT_SOUNDS = {
    "HTT_zombie_reaction_01",
    "HTT_zombie_reaction_02",
    "HTT_zombie_reaction_03",
}

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    nextRotorHour = 0,
    nextShotHour = 0,
    nextCenterSyncHour = 0,
    pendingHits = {},
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.nextRotorHour = 0
    runtime.nextShotHour = 0
    runtime.nextCenterSyncHour = 0
    runtime.pendingHits = {}
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

local function killZombieSafe(zombie, killer)
    if not zombie then
        return false
    end

    if zombie:isDead() then
        return true
    end

    if killer and zombie.setAttackedBy then
        pcall(function()
            zombie:setAttackedBy(killer)
        end)
    end

    if zombie.Kill then
        pcall(function()
            zombie:Kill(killer)
        end)
    end

    if zombie:isDead() then
        return true
    end

    if zombie.DoDeath then
        pcall(function()
            zombie:DoDeath(nil, killer, true)
        end)
    end

    if zombie:isDead() then
        return true
    end

    if zombie.setHealth then
        pcall(function()
            zombie:setHealth(0)
        end)
    end

    local bd = zombie.getBodyDamage and zombie:getBodyDamage() or nil
    if bd and bd.setOverallBodyHealth then
        pcall(function()
            bd:setOverallBodyHealth(0)
        end)
    end

    if zombie.Kill and not zombie:isDead() then
        pcall(function()
            zombie:Kill(nil)
        end)
    end

    if zombie:isDead() or (zombie.isAlive and not zombie:isAlive()) then
        return true
    end

    local removed = false
    if zombie.removeFromWorld then
        local ok = pcall(function()
            zombie:removeFromWorld()
        end)
        removed = removed or ok
    end
    if zombie.removeFromSquare then
        local ok = pcall(function()
            zombie:removeFromSquare()
        end)
        removed = removed or ok
    end

    return removed
end

local function updateDynamicCenter(state, now)
    if runtime.nextCenterSyncHour > 0 and now < runtime.nextCenterSyncHour then
        return
    end
    runtime.nextCenterSyncHour = now + secondsToWorldHoursSafe(
        SNIPER_FOLLOW_SYNC_SECONDS,
        SNIPER_FOLLOW_SYNC_SECONDS
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

local function broadcastSniperSound(state, soundName, radius, x, y, z, extraArgs)
    if not soundName or soundName == "" then
        return false
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return false
    end

    local soundRadius = HTT.toNumber(radius, HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius))
    if soundRadius <= 0 then
        soundRadius = HTT.Config.DefaultSoundRadius
    end

    local mergedArgs = {}
    if type(extraArgs) == "table" then
        for k, v in pairs(extraArgs) do
            mergedArgs[k] = v
        end
    end
    mergedArgs.eventId = state and state.eventId or "sniper_cover_event"
    if mergedArgs.attachToFollowPlayer == nil then
        mergedArgs.attachToFollowPlayer = true
    end
    if mergedArgs.followOnlineId == nil then
        mergedArgs.followOnlineId = state and state.followOnlineId or nil
    end

    return HTT.Server.broadcastSound(
        soundName,
        HTT.toNumber(x, state.centerX),
        HTT.toNumber(y, state.centerY),
        HTT.toNumber(z, state.centerZ),
        soundRadius,
        mergedArgs
    )
end

local function getShotIntervalHours()
    local minSeconds = math.max(1.0, HTT.toNumber(SNIPER_SHOT_MIN_SECONDS, 8.0))
    local maxSeconds = math.max(minSeconds, HTT.toNumber(SNIPER_SHOT_MAX_SECONDS, 16.0))
    local delaySeconds = ZombRandFloat(minSeconds, maxSeconds)
    return secondsToWorldHoursSafe(delaySeconds, delaySeconds)
end

local function pickSniperTarget(state, referencePlayer)
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end

    local zombies = cell:getZombieList()
    if not zombies or zombies:size() <= 0 then
        return nil
    end

    local cx = HTT.toNumber(referencePlayer and referencePlayer:getX(), HTT.toNumber(state.centerX, 0))
    local cy = HTT.toNumber(referencePlayer and referencePlayer:getY(), HTT.toNumber(state.centerY, 0))
    local cz = HTT.toNumber(referencePlayer and referencePlayer:getZ(), HTT.toNumber(state.centerZ, 0))
    local limit = SNIPER_TARGET_RADIUS * SNIPER_TARGET_RADIUS
    local closeLimit = math.min(SNIPER_TARGET_RADIUS, SNIPER_PRIORITY_CLOSE_RADIUS)
    local closeLimitSq = closeLimit * closeLimit
    local bestZombie = nil
    local bestScore = nil
    local closeZombie = nil
    local closeScore = nil

    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dz = math.abs(HTT.toNumber(zombie:getZ(), 0) - cz)
            if dz <= 2 then
                local dx = zombie:getX() - cx
                local dy = zombie:getY() - cy
                local distSq = dx * dx + dy * dy
                if distSq <= limit then
                    local score = distSq + (dz * 4.0)
                    if not bestScore or score < bestScore then
                        bestScore = score
                        bestZombie = zombie
                    end
                    if distSq <= closeLimitSq and (not closeScore or score < closeScore) then
                        closeScore = score
                        closeZombie = zombie
                    end
                end
            end
        end
    end

    return closeZombie or bestZombie
end

local function hasNearbyZombie(state)
    local cell = getCell and getCell() or nil
    if not cell then
        return false
    end

    local zombies = cell:getZombieList()
    if not zombies or zombies:size() <= 0 then
        return false
    end

    local cx = HTT.toNumber(state and state.centerX, 0)
    local cy = HTT.toNumber(state and state.centerY, 0)
    local cz = HTT.toNumber(state and state.centerZ, 0)
    local limit = SNIPER_TARGET_RADIUS * SNIPER_TARGET_RADIUS

    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dz = math.abs(HTT.toNumber(zombie:getZ(), 0) - cz)
            if dz <= 2 then
                local dx = zombie:getX() - cx
                local dy = zombie:getY() - cy
                if (dx * dx + dy * dy) <= limit then
                    return true
                end
            end
        end
    end

    return false
end

local function applySniperDamage(zombie, killer)
    local killed = killZombieSafe(zombie, killer)
    HTT.log("Sniper kill result=" .. tostring(killed))
    return killed
end

local function queueHitSound(zombie, now)
    if not zombie then
        return
    end

    local index = ZombRand(#SNIPER_HIT_SOUNDS) + 1
    local delaySeconds = ZombRandFloat(
        SNIPER_HIT_SOUND_DELAY_MIN_SECONDS,
        SNIPER_HIT_SOUND_DELAY_MAX_SECONDS
    )
    local delay = secondsToWorldHoursSafe(delaySeconds, delaySeconds)
    local pitch = 1.0 + ZombRandFloat(-SNIPER_HIT_PITCH_VARIATION, SNIPER_HIT_PITCH_VARIATION)
    local volume = 1.0 + ZombRandFloat(-SNIPER_HIT_VOLUME_VARIATION, SNIPER_HIT_VOLUME_VARIATION)
    runtime.pendingHits[#runtime.pendingHits + 1] = {
        hour = HTT.toNumber(now, 0) + delay,
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        sound = SNIPER_HIT_SOUNDS[index],
        pitch = pitch,
        volume = volume,
    }
end

local function processPendingHitSounds(state, now)
    local pending = runtime.pendingHits
    if not pending or #pending <= 0 then
        return
    end

    local hasAnyNearbyTarget = hasNearbyZombie(state)
    for i = #pending, 1, -1 do
        local entry = pending[i]
        if now >= HTT.toNumber(entry and entry.hour, now + 1) then
            if hasAnyNearbyTarget then
                broadcastSniperSound(
                    state,
                    entry and entry.sound or nil,
                    SNIPER_HIT_SOUND_RADIUS,
                    entry and entry.x or nil,
                    entry and entry.y or nil,
                    entry and entry.z or nil,
                    {
                        pitch = HTT.toNumber(entry and entry.pitch, 1.0),
                        volumeMul = HTT.toNumber(entry and entry.volume, 1.0),
                        attachToFollowPlayer = false,
                    }
                )
            end
            pending[i] = pending[#pending]
            pending[#pending] = nil
        end
    end
end

local function playRotorLoopIfNeeded(state, eventDef, now)
    local nextRotor = HTT.toNumber(runtime.nextRotorHour, 0)
    if nextRotor > 0 and now < nextRotor then
        return
    end

    runtime.nextRotorHour = now + secondsToWorldHoursSafe(
        SNIPER_ROTOR_REPEAT_SECONDS,
        SNIPER_ROTOR_REPEAT_SECONDS
    )

    local rotorSound = eventDef and eventDef.startSound or "HTT_loop_tactical_rotor"
    local radius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 20,
        HTT.Config.DefaultSoundRadius + 12
    )
    broadcastSniperSound(state, rotorSound, radius)
end

local function fireSniperShot(state, eventDef, now)
    local shooterTarget = resolveFollowPlayer(state)
    local target = pickSniperTarget(state, shooterTarget)
    if not target then
        return false
    end

    local shotSound = eventDef and eventDef.fireSound or "HTT_precision_rifle"
    local fired = broadcastSniperSound(
        state,
        shotSound,
        SNIPER_SHOT_SOUND_RADIUS,
        target:getX(),
        target:getY(),
        target:getZ()
    )
    if not fired then
        return false
    end

    applySniperDamage(target, shooterTarget)
    queueHitSound(target, now)
    return true
end

local function sniperCoverTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "sniper_cover_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "actionHour", "nextRotorHour", "nextShotHour", "nextCenterSyncHour" },
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

    local eventDef = HTT.getEventDefinition("sniper_cover_event")
    if not eventDef then
        return
    end

    local eventStart = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStart then
        runtime.eventStartHour = eventStart
        runtime.actionHour = eventStart + secondsToWorldHoursSafe(
            SNIPER_APPROACH_SECONDS,
            SNIPER_APPROACH_SECONDS
        )
        runtime.nextRotorHour = eventStart + secondsToWorldHoursSafe(
            SNIPER_ROTOR_REPEAT_SECONDS,
            SNIPER_ROTOR_REPEAT_SECONDS
        )
        runtime.nextShotHour = runtime.actionHour
        runtime.nextCenterSyncHour = 0
        runtime.pendingHits = {}
    end

    updateDynamicCenter(state, now)
    playRotorLoopIfNeeded(state, eventDef, now)
    processPendingHitSounds(state, now)

    if now < HTT.toNumber(runtime.actionHour, now) then
        return
    end

    if now < HTT.toNumber(runtime.nextShotHour, now) then
        return
    end

    local firedShot = fireSniperShot(state, eventDef, now)
    if firedShot then
        runtime.nextShotHour = now + getShotIntervalHours()
    else
        runtime.nextShotHour = now + secondsToWorldHoursSafe(
            SNIPER_RETRY_NO_TARGET_SECONDS,
            SNIPER_RETRY_NO_TARGET_SECONDS
        )
    end
end

local sniperTickHooked = registerEvent("OnTick", sniperCoverTick)
if not sniperTickHooked then
    registerEvent("EveryOneMinute", sniperCoverTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server sniper cover system loaded (hook=" .. tostring(sniperTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
