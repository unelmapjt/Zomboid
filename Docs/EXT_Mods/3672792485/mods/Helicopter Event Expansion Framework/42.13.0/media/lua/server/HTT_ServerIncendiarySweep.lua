require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerIncendiarySweep = HTT.ServerIncendiarySweep or {}

if HTT._serverIncendiarySweepLoaded then
    return
end
HTT._serverIncendiarySweepLoaded = true

local INCENDIARY_APPROACH_SECONDS = 30.0
local SWEEP_INTERVAL_SECONDS = 8.0
local SWEEP_COUNT_PER_EVENT = 6
local MIN_DISTANCE_FROM_PLAYER = 24
local MAX_DISTANCE_FROM_PLAYER = 75
local FIRE_PATCHES_PER_SWEEP = 18
local FIRE_SPREAD_RADIUS = 14
local ZOMBIE_IGNITE_RADIUS = 14
local MAX_ZOMBIES_TO_IGNITE = 35
local ATTRACT_RADIUS = 260
local ATTRACT_VOLUME = 220

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    nextSweepHour = 0,
    sweepsLeft = 0,
}
local fireCleanup = {
    trackedSquares = {},
    pending = false,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.nextSweepHour = 0
    runtime.sweepsLeft = 0
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

local function getNowWorldHourSafe()
    local gt = getGameTime and getGameTime() or nil
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return gt:getWorldAgeHours()
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

local function isPointNearAnyPlayer(x, y, minDistance)
    local pointX = HTT.toNumber(x, 0)
    local pointY = HTT.toNumber(y, 0)
    local minDist = HTT.toNumber(minDistance, MIN_DISTANCE_FROM_PLAYER)
    if minDist == nil then
        minDist = MIN_DISTANCE_FROM_PLAYER
    end
    if minDist <= 0 then
        return false
    end
    local minDistSq = minDist * minDist

    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() then
                local dx = pointX - p:getX()
                local dy = pointY - p:getY()
                if (dx * dx + dy * dy) < minDistSq then
                    return true
                end
            end
        end
        return false
    end

    if getPlayer then
        local p = getPlayer()
        if p and not p:isDead() then
            local dx = pointX - p:getX()
            local dy = pointY - p:getY()
            if (dx * dx + dy * dy) < minDistSq then
                return true
            end
        end
    end

    return false
end

local function getLoadedSquare(x, y, z)
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end

    return cell:getGridSquare(
        math.floor(HTT.toNumber(x, 0) + 0.5),
        math.floor(HTT.toNumber(y, 0) + 0.5),
        math.floor(HTT.toNumber(z, 0) + 0.5)
    )
end

local function getTrackedSquareKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function trackStartedFireSquare(square)
    if not square then
        return false
    end

    local x = square.getX and square:getX() or nil
    local y = square.getY and square:getY() or nil
    local z = square.getZ and square:getZ() or nil
    if x == nil or y == nil or z == nil then
        return false
    end

    local key = getTrackedSquareKey(x, y, z)
    fireCleanup.trackedSquares[key] = {
        x = math.floor(x),
        y = math.floor(y),
        z = math.floor(z),
    }
    fireCleanup.pending = true
    return true
end

local function pickSweepPoint(state, player, minDistanceFromPlayers)
    local minDist = HTT.toNumber(minDistanceFromPlayers, MIN_DISTANCE_FROM_PLAYER)
    if minDist == nil then
        minDist = MIN_DISTANCE_FROM_PLAYER
    end
    if minDist < 0 then
        minDist = 0
    end
    local maxDist = MAX_DISTANCE_FROM_PLAYER
    if maxDist < minDist then
        maxDist = minDist
    end

    local baseX = player and player:getX() or HTT.toNumber(state.centerX, 0)
    local baseY = player and player:getY() or HTT.toNumber(state.centerY, 0)
    local baseZ = player and player:getZ() or HTT.toNumber(state.centerZ, 0)

    local attemptX = baseX
    local attemptY = baseY
    local minDistSq = minDist * minDist
    local foundLoadedPoint = false
    local fallbackSafeX = nil
    local fallbackSafeY = nil

    for _ = 1, 22 do
        local angle = ZombRandFloat(0, math.pi * 2)
        local distance = ZombRandFloat(minDist, maxDist)
        attemptX = baseX + math.cos(angle) * distance
        attemptY = baseY + math.sin(angle) * distance
        local dx = attemptX - baseX
        local dy = attemptY - baseY
        if (dx * dx + dy * dy) >= minDistSq and not isPointNearAnyPlayer(attemptX, attemptY, minDist) then
            fallbackSafeX = attemptX
            fallbackSafeY = attemptY
            if getLoadedSquare(attemptX, attemptY, baseZ) then
                foundLoadedPoint = true
                break
            end
        end
    end

    if not foundLoadedPoint then
        if fallbackSafeX ~= nil and fallbackSafeY ~= nil then
            attemptX = fallbackSafeX
            attemptY = fallbackSafeY
        else
            local angle = ZombRandFloat(0, math.pi * 2)
            attemptX = baseX + math.cos(angle) * minDist
            attemptY = baseY + math.sin(angle) * minDist
        end
    end

    return attemptX, attemptY, baseZ
end

local function getSweepPlayerSafetyDistance()
    local riskEnabled = HTT.Config and HTT.Config.EnableIncendiarySweepPlayerRisk == true
    if not riskEnabled then
        return MIN_DISTANCE_FROM_PLAYER, false
    end

    -- Risk mode: each sweep uses a random minimum distance to players.
    local randomMinDistance = ZombRandFloat(0, MIN_DISTANCE_FROM_PLAYER)
    return randomMinDistance, true
end

local function broadcastApproachSound(state, eventDef)
    if not eventDef or not eventDef.startSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 45,
        HTT.Config.DefaultSoundRadius + 35
    )
    HTT.Server.broadcastSound(
        eventDef.startSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "incendiary_sweep",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function broadcastActionSound(state, eventDef, x, y, z)
    if not eventDef or not eventDef.actionSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 45,
        HTT.Config.DefaultSoundRadius + 35
    )
    HTT.Server.broadcastSound(
        eventDef.actionSound,
        HTT.toNumber(x, state.centerX),
        HTT.toNumber(y, state.centerY),
        HTT.toNumber(z, state.centerZ),
        soundRadius,
        {
            eventId = "incendiary_sweep",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function canCheckSquareFire(square)
    if not square then
        return false
    end
    return square.isBurning ~= nil
        or square.haveFire ~= nil
        or square.hasFire ~= nil
        or square.HasFire ~= nil
end

local function squareHasActiveFire(square)
    if not square then
        return false
    end

    if square.isBurning then
        local ok, burning = pcall(square.isBurning, square)
        if ok and burning then
            return true
        end
    end

    if square.haveFire then
        local ok, hasFire = pcall(square.haveFire, square)
        if ok and hasFire then
            return true
        end
    end

    if square.hasFire then
        local ok, hasFire = pcall(square.hasFire, square)
        if ok and hasFire then
            return true
        end
    end

    if square.HasFire then
        local ok, hasFire = pcall(square.HasFire, square)
        if ok and hasFire then
            return true
        end
    end

    return false
end

local function stopTrackedFireOnSquare(square)
    if not square then
        return false
    end

    local changed = false
    if IsoFireManager and IsoFireManager.RemoveAllOn then
        local ok = pcall(IsoFireManager.RemoveAllOn, square)
        if ok then
            changed = true
        end
    end

    if square.stopFire then
        local ok = pcall(square.stopFire, square)
        if ok then
            changed = true
        end
    end

    if square.transmitStopFire then
        pcall(square.transmitStopFire, square)
    end

    return changed or not squareHasActiveFire(square)
end

local function hasTrackedFireSquares()
    for _, _ in pairs(fireCleanup.trackedSquares) do
        return true
    end
    return false
end

local function queueTrackedFireCleanup()
    fireCleanup.pending = hasTrackedFireSquares()
    return fireCleanup.pending
end

local function cleanupTrackedFires(reason)
    if fireCleanup.pending ~= true then
        return 0
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return 0
    end

    local cleaned = 0
    local remaining = 0
    for key, entry in pairs(fireCleanup.trackedSquares) do
        local square = cell:getGridSquare(entry.x, entry.y, entry.z)
        if square then
            stopTrackedFireOnSquare(square)
            fireCleanup.trackedSquares[key] = nil
            cleaned = cleaned + 1
        else
            remaining = remaining + 1
        end
    end

    fireCleanup.pending = hasTrackedFireSquares()

    if cleaned > 0 then
        HTT.log(string.format(
            "Incendiary sweep fire cleanup reason=%s cleaned=%d remaining=%d",
            tostring(reason or "unspecified"),
            cleaned,
            remaining
        ))
    end

    return cleaned
end

local function tryStartFireOnSquare(square)
    if not square then
        return false
    end

    local cell = getCell and getCell() or nil
    local attempted = false

    local function fireCall(fn, ...)
        if not fn then
            return false
        end
        local ok = pcall(fn, ...)
        if ok then
            attempted = true
            if squareHasActiveFire(square) then
                return true
            end
        end
        return false
    end

    if IsoFireManager and IsoFireManager.StartFire and cell then
        if fireCall(IsoFireManager.StartFire, cell, square, true, 60, 380) then
            return true
        end
        if fireCall(IsoFireManager.StartFire, cell, square, true, 60) then
            return true
        end
        if fireCall(IsoFireManager.StartFire, cell, square, true) then
            return true
        end
    end

    if addFire then
        if fireCall(addFire, square, true, 55, 280) then
            return true
        end
        if fireCall(addFire, square, true, 55) then
            return true
        end
        if fireCall(addFire, square, true) then
            return true
        end
    end

    if square.startFire then
        if fireCall(square.startFire, square) then
            return true
        end
    end
    if square.StartFire then
        if fireCall(square.StartFire, square) then
            return true
        end
    end

    if square.burn then
        if fireCall(square.burn, square, true) then
            return true
        end
    end

    if canCheckSquareFire(square) then
        return squareHasActiveFire(square)
    end

    return attempted
end

local function tryIgniteZombie(zombie)
    if not zombie or zombie:isDead() then
        return false
    end

    if zombie.setOnFire then
        local ok = pcall(zombie.setOnFire, zombie, true)
        if ok then
            return true
        end
        ok = pcall(zombie.setOnFire, zombie)
        if ok then
            return true
        end
    end

    if zombie.SetOnFire then
        local ok = pcall(zombie.SetOnFire, zombie, true)
        if ok then
            return true
        end
        ok = pcall(zombie.SetOnFire, zombie)
        if ok then
            return true
        end
    end

    if zombie.ignite then
        local ok = pcall(zombie.ignite, zombie)
        if ok then
            return true
        end
    end

    if zombie.Ignite then
        local ok = pcall(zombie.Ignite, zombie)
        if ok then
            return true
        end
    end

    return false
end

local function igniteNearbyZombies(centerX, centerY, radius)
    local cell = getCell()
    if not cell then
        return 0
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return 0
    end

    local limit = radius * radius
    local ignited = 0
    for i = zombies:size() - 1, 0, -1 do
        if ignited >= MAX_ZOMBIES_TO_IGNITE then
            break
        end

        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dx = zombie:getX() - centerX
            local dy = zombie:getY() - centerY
            if (dx * dx + dy * dy) <= limit then
                if tryIgniteZombie(zombie) then
                    ignited = ignited + 1
                end
            end
        end
    end

    return ignited
end

local function spawnFirePatches(centerX, centerY, centerZ, minDistanceFromPlayers)
    local cell = getCell()
    if not cell then
        return 0
    end

    local safeDistance = HTT.toNumber(minDistanceFromPlayers, MIN_DISTANCE_FROM_PLAYER)
    local started = 0
    local attempts = FIRE_PATCHES_PER_SWEEP * 4
    for _ = 1, attempts do
        if started >= FIRE_PATCHES_PER_SWEEP then
            break
        end

        local angle = ZombRandFloat(0, math.pi * 2)
        local dist = ZombRandFloat(0, FIRE_SPREAD_RADIUS)
        local x = math.floor((centerX + math.cos(angle) * dist) + 0.5)
        local y = math.floor((centerY + math.sin(angle) * dist) + 0.5)
        local z = math.floor(HTT.toNumber(centerZ, 0) + 0.5)
        if not isPointNearAnyPlayer(x, y, safeDistance) then
            local square = cell:getGridSquare(x, y, z)
            local hadFireBefore = squareHasActiveFire(square)
            if not hadFireBefore and tryStartFireOnSquare(square) then
                trackStartedFireSquare(square)
                started = started + 1
            end
        end
    end

    return started
end

local function emitAttractSound(x, y, z)
    if not addSound then
        return
    end

    addSound(
        nil,
        math.floor(HTT.toNumber(x, 0)),
        math.floor(HTT.toNumber(y, 0)),
        math.floor(HTT.toNumber(z, 0)),
        ATTRACT_RADIUS,
        ATTRACT_VOLUME
    )
end

local function runSweep(state, eventDef, now)
    local player = resolveReferencePlayer(state)
    local safeDistance, allowPlayerRisk = getSweepPlayerSafetyDistance()
    local sx, sy, sz = pickSweepPoint(state, player, safeDistance)

    state.centerX = sx
    state.centerY = sy
    state.centerZ = sz
    if HTT.Server and HTT.Server.broadcastEventState then
        HTT.Server.broadcastEventState()
    end

    broadcastActionSound(state, eventDef, sx, sy, sz)

    local fireCount = spawnFirePatches(sx, sy, sz, safeDistance)
    local ignited = igniteNearbyZombies(sx, sy, ZOMBIE_IGNITE_RADIUS)
    emitAttractSound(sx, sy, sz)
    emitAttractSound(sx, sy, sz)

    if fireCount <= 0 then
        for _ = 1, 3 do
            local altX, altY, altZ = pickSweepPoint(state, player, safeDistance)
            local altFires = spawnFirePatches(altX, altY, altZ, safeDistance)
            if altFires > 0 then
                fireCount = fireCount + altFires
                ignited = ignited + igniteNearbyZombies(altX, altY, ZOMBIE_IGNITE_RADIUS)
                emitAttractSound(altX, altY, altZ)
                sx, sy, sz = altX, altY, altZ
                state.centerX = sx
                state.centerY = sy
                state.centerZ = sz
                if HTT.Server and HTT.Server.broadcastEventState then
                    HTT.Server.broadcastEventState()
                end
                break
            end
        end
    end

    if fireCount <= 0 then
        -- Final fallback pulse near sweep center so the event stays observable.
        fireCount = fireCount + spawnFirePatches(sx, sy, sz, safeDistance)
    end

    runtime.sweepsLeft = runtime.sweepsLeft - 1
    HTT.log(string.format(
        "Incendiary sweep at (%.1f, %.1f, %.1f) fires=%d ignited=%d sweepsLeft=%d playerRisk=%s randomMinDist=%.1f",
        sx,
        sy,
        sz,
        fireCount,
        ignited,
        math.max(0, runtime.sweepsLeft),
        tostring(allowPlayerRisk),
        safeDistance
    ))

    if runtime.sweepsLeft <= 0 then
        if HTT.Server and HTT.Server.stopEvent then
            queueTrackedFireCleanup()
            HTT.Server.stopEvent("incendiary-sweep-complete")
        end
        return
    end

    runtime.nextSweepHour = now + secondsToWorldHoursSafe(SWEEP_INTERVAL_SECONDS, SWEEP_INTERVAL_SECONDS)
end

local function incendiaryTick()
    if not HTT.Server or not HTT.Server.state then
        cleanupTrackedFires("server-missing")
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "incendiary_sweep" then
        cleanupTrackedFires("event-inactive")
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(runtime, { "actionHour", "nextSweepHour" }, now)
        end
        return
    end

    if now >= state.endHour then
        if HTT.Server and HTT.Server.stopEvent then
            queueTrackedFireCleanup()
            HTT.Server.stopEvent("duration-expired")
        end
        resetRuntime()
        return
    end

    local eventDef = HTT.getEventDefinition("incendiary_sweep")
    if not eventDef then
        return
    end

    local eventStartHour = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStartHour then
        runtime.eventStartHour = eventStartHour
        runtime.actionHour = eventStartHour + secondsToWorldHoursSafe(
            INCENDIARY_APPROACH_SECONDS,
            INCENDIARY_APPROACH_SECONDS
        )
        runtime.nextSweepHour = runtime.actionHour
        runtime.sweepsLeft = SWEEP_COUNT_PER_EVENT
        broadcastApproachSound(state, eventDef)
    end

    if runtime.sweepsLeft <= 0 then
        return
    end

    if now < HTT.toNumber(runtime.actionHour, now) then
        return
    end

    if now >= HTT.toNumber(runtime.nextSweepHour, now) then
        runSweep(state, eventDef, now)
    end
end

local incendiaryTickHooked = registerEvent("OnTick", incendiaryTick)
if not incendiaryTickHooked then
    registerEvent("EveryOneMinute", incendiaryTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server incendiary sweep system loaded (hook=" .. tostring(incendiaryTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
