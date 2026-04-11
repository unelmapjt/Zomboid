require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerBombardment = HTT.ServerBombardment or {}

if HTT._serverBombardmentLoaded then
    return
end
HTT._serverBombardmentLoaded = true

local runtime = {
    eventStartHour = 0,
    phase = "idle",
    nextStrikeHour = 0,
    pendingExplosionHour = 0,
    endEventHour = 0,
    strikeX = 0,
    strikeY = 0,
    strikeZ = 0,
    strikeCompleted = false,
    strikeCount = 0,
    startSoundPlayed = false,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.phase = "idle"
    runtime.nextStrikeHour = 0
    runtime.pendingExplosionHour = 0
    runtime.endEventHour = 0
    runtime.strikeX = 0
    runtime.strikeY = 0
    runtime.strikeZ = 0
    runtime.strikeCompleted = false
    runtime.strikeCount = 0
    runtime.startSoundPlayed = false
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

local function minutesToWorldHoursSafe(minutes, fallbackMinutes)
    local mins = HTT.toNumber(minutes, fallbackMinutes)
    if mins == nil or mins <= 0 then
        return 0
    end

    return secondsToWorldHoursSafe(mins * 60.0, mins * 60.0)
end

local function getBombardmentPassToExplosionHours()
    local passDelaySec = HTT.toNumber(HTT.Config.BombardmentPassToExplosionSeconds, 2.0)
    if passDelaySec < 0.25 then
        passDelaySec = 0.25
    end
    return secondsToWorldHoursSafe(passDelaySec, 2.0)
end

local function getBombardmentPostExplosionEndHours()
    local endDelaySec = HTT.toNumber(HTT.Config.BombardmentPostExplosionEndSeconds, 5.0)
    if endDelaySec < 0 then
        endDelaySec = 0
    end
    return secondsToWorldHoursSafe(endDelaySec, 5.0)
end

local function getBombardmentStrikeIntervalHours()
    local strikeIntervalMinutes = HTT.toNumber(HTT.Config.BombardmentStrikeIntervalMinutes, 0.55)
    if strikeIntervalMinutes <= 0 then
        strikeIntervalMinutes = 0.55
    end

    return math.max(
        minutesToWorldHoursSafe(strikeIntervalMinutes, 0.55),
        secondsToWorldHoursSafe(12.0, 12.0)
    )
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

local function pickStrikePoint(state, player)
    local minDist = HTT.toNumber(HTT.Config.BombardmentMinDistanceFromPlayer, 30)
    local maxDist = HTT.toNumber(HTT.Config.BombardmentMaxDistanceFromPlayer, 78)
    if minDist < 8 then
        minDist = 8
    end
    if maxDist < minDist then
        maxDist = minDist
    end

    local baseX = player and player:getX() or HTT.toNumber(state.centerX, 0)
    local baseY = player and player:getY() or HTT.toNumber(state.centerY, 0)
    local baseZ = player and player:getZ() or HTT.toNumber(state.centerZ, 0)

    local minDistSq = minDist * minDist
    local attemptX = baseX
    local attemptY = baseY
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

local function setStrikePoint(state, x, y, z)
    runtime.strikeX = HTT.toNumber(x, runtime.strikeX)
    runtime.strikeY = HTT.toNumber(y, runtime.strikeY)
    runtime.strikeZ = HTT.toNumber(z, runtime.strikeZ)
    state.centerX = runtime.strikeX
    state.centerY = runtime.strikeY
    state.centerZ = runtime.strikeZ
    if HTT.Server and HTT.Server.broadcastEventState then
        HTT.Server.broadcastEventState()
    end
end

local function chooseNextStrikePoint(state)
    local player = resolveReferencePlayer(state)
    local x, y, z = pickStrikePoint(state, player)
    setStrikePoint(state, x, y, z)
end

local function killZombieSafe(zombie)
    if not zombie or zombie:isDead() then
        return false
    end

    if zombie.Kill then
        pcall(function()
            zombie:Kill(nil)
        end)
    end
    if not zombie:isDead() and zombie.setHealth then
        pcall(function()
            zombie:setHealth(0)
        end)
    end

    return zombie:isDead() or HTT.toNumber(zombie.getHealth and zombie:getHealth() or 0, 0) <= 0
end

local function pickZombieCandidates(centerX, centerY, radius)
    local cell = getCell()
    if not cell then
        return {}
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return {}
    end

    local limit = radius * radius
    local candidates = {}
    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dx = zombie:getX() - centerX
            local dy = zombie:getY() - centerY
            if (dx * dx + dy * dy) <= limit then
                candidates[#candidates + 1] = zombie
            end
        end
    end

    return candidates
end

local function pickRandomSubset(list, maxCount)
    local count = math.min(#list, math.max(0, maxCount))
    if count <= 0 then
        return {}
    end

    local pool = {}
    for i = 1, #list do
        pool[i] = list[i]
    end

    local picked = {}
    for _ = 1, count do
        if #pool <= 0 then
            break
        end

        local idx = ZombRand(#pool) + 1
        picked[#picked + 1] = pool[idx]
        pool[idx] = pool[#pool]
        pool[#pool] = nil
    end

    return picked
end

local function tryIgniteZombie(zombie)
    if not zombie then
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

local function applyStrikeDamage(strikeX, strikeY)
    local strikeRadius = HTT.toNumber(HTT.Config.BombardmentStrikeRadius, 14)
    if strikeRadius < 4 then
        strikeRadius = 4
    end

    local instantKills = math.floor(HTT.toNumber(HTT.Config.BombardmentInstantKillCount, 14))
    if instantKills < 0 then
        instantKills = 0
    end

    local burnTargets = math.floor(HTT.toNumber(HTT.Config.BombardmentBurnTargetsPerStrike, 20))
    if burnTargets < 0 then
        burnTargets = 0
    end

    local burnMin = HTT.toNumber(HTT.Config.BombardmentBurnDamageMin, 0.25)
    local burnMax = HTT.toNumber(HTT.Config.BombardmentBurnDamageMax, 0.85)
    if burnMax < burnMin then
        burnMax = burnMin
    end

    local candidates = pickZombieCandidates(strikeX, strikeY, strikeRadius)
    if #candidates <= 0 then
        return 0, 0, 0
    end

    local killed = 0
    local burned = 0

    local killedMap = {}
    local killList = pickRandomSubset(candidates, instantKills)
    for i = 1, #killList do
        local zombie = killList[i]
        if zombie and not zombie:isDead() and killZombieSafe(zombie) then
            killedMap[zombie] = true
            killed = killed + 1
        end
    end

    local burnPool = {}
    for i = 1, #candidates do
        local zombie = candidates[i]
        if zombie and not zombie:isDead() and not killedMap[zombie] then
            burnPool[#burnPool + 1] = zombie
        end
    end

    local burnList = pickRandomSubset(burnPool, burnTargets)
    for i = 1, #burnList do
        local zombie = burnList[i]
        if zombie and not zombie:isDead() then
            local damage = ZombRandFloat(burnMin, burnMax)
            local nextHealth = zombie:getHealth() - damage
            if nextHealth <= 0 then
                if killZombieSafe(zombie) then
                    killed = killed + 1
                end
            else
                zombie:setHealth(nextHealth)
                tryIgniteZombie(zombie)
                burned = burned + 1
            end
        end
    end

    return killed, burned, #candidates
end

local function getBombardSoundRadius(state)
    local configured = HTT.toNumber(HTT.Config.BombardmentSoundRadius, 120)
    if configured > 0 then
        return configured
    end

    local base = HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius)
    return math.max(base + 45, HTT.Config.DefaultSoundRadius + 30)
end

local function broadcastBombardSound(state, soundName, x, y, z, indicator)
    if not soundName or soundName == "" then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local extraArgs = nil
    if indicator then
        local isDefaultIndicator = indicator == true
        extraArgs = {
            indicator = true,
            indicatorKind = "bombardment",
            indicatorText = tostring(HTT.Config.BombardmentIndicatorText or "BOOM"),
            indicatorDuration = HTT.toNumber(HTT.Config.BombardmentIndicatorDurationSeconds, 5.0),
            indicatorR = 1.0,
            indicatorG = 0.38,
            indicatorB = 0.15,
        }

        if not isDefaultIndicator and type(indicator) == "table" then
            if indicator.text ~= nil then
                extraArgs.indicatorText = tostring(indicator.text)
            end
            if indicator.duration ~= nil then
                extraArgs.indicatorDuration = HTT.toNumber(
                    indicator.duration,
                    extraArgs.indicatorDuration
                )
            end
            if indicator.r ~= nil then
                extraArgs.indicatorR = HTT.toNumber(indicator.r, extraArgs.indicatorR)
            end
            if indicator.g ~= nil then
                extraArgs.indicatorG = HTT.toNumber(indicator.g, extraArgs.indicatorG)
            end
            if indicator.b ~= nil then
                extraArgs.indicatorB = HTT.toNumber(indicator.b, extraArgs.indicatorB)
            end
            if indicator.kind ~= nil then
                extraArgs.indicatorKind = tostring(indicator.kind)
            end
        end
    end

    local eventDef = HTT.getEventDefinition and HTT.getEventDefinition(state and state.eventId or "air_bombardment") or nil
    if eventDef and soundName == tostring(eventDef.startSound or "") then
        extraArgs = extraArgs or {}
        extraArgs.eventId = state and state.eventId or "air_bombardment"
        extraArgs.attachToFollowPlayer = true
        extraArgs.followOnlineId = state and state.followOnlineId or nil
    end

    HTT.Server.broadcastSound(
        soundName,
        HTT.toNumber(x, state.centerX),
        HTT.toNumber(y, state.centerY),
        HTT.toNumber(z, state.centerZ),
        getBombardSoundRadius(state),
        extraArgs
    )
end

local function initRuntimeIfNeeded(state, now)
    if runtime.eventStartHour == HTT.toNumber(state.startHour, 0) then
        return
    end

    runtime.eventStartHour = HTT.toNumber(state.startHour, now)
    runtime.phase = "approach"
    runtime.pendingExplosionHour = 0
    runtime.endEventHour = 0
    runtime.strikeCompleted = false
    runtime.strikeCount = 0
    runtime.startSoundPlayed = false

    chooseNextStrikePoint(state)

    local rotorToPassSec = HTT.toNumber(HTT.Config.BombardmentRotorToPassSeconds, nil)
    if rotorToPassSec ~= nil then
        if rotorToPassSec < 0 then
            rotorToPassSec = 0
        end
        -- Keep the first audible pass reasonably close to event start.
        if rotorToPassSec > 30.0 then
            rotorToPassSec = 30.0
        end
        runtime.nextStrikeHour = now + secondsToWorldHoursSafe(rotorToPassSec, 45.0)
    else
        local firstDelay = HTT.toNumber(HTT.Config.BombardmentFirstStrikeDelayMinutes, 0.12)
        if firstDelay < 0 then
            firstDelay = 0
        end
        runtime.nextStrikeHour = now + minutesToWorldHoursSafe(firstDelay, 0.12)
    end
end

local function playApproachStartIfNeeded(state, eventDef)
    if runtime.startSoundPlayed then
        return
    end

    runtime.startSoundPlayed = true
    local startSound = (eventDef and eventDef.startSound) or "HTT_heli_loop_far"
    broadcastBombardSound(
        state,
        startSound,
        runtime.strikeX,
        runtime.strikeY,
        runtime.strikeZ,
        false
    )
end

local function startStrikePass(state, eventDef, now)
    local player = resolveReferencePlayer(state)
    if player then
        local minDist = HTT.toNumber(HTT.Config.BombardmentMinDistanceFromPlayer, 30)
        if minDist < 8 then
            minDist = 8
        end
        local dx = runtime.strikeX - player:getX()
        local dy = runtime.strikeY - player:getY()
        if (dx * dx + dy * dy) < (minDist * minDist) then
            local x, y, z = pickStrikePoint(state, player)
            setStrikePoint(state, x, y, z)
        end
    end

    runtime.pendingExplosionHour = now + getBombardmentPassToExplosionHours()
    runtime.phase = "active"
    runtime.nextStrikeHour = 0

    local passSound = (eventDef and eventDef.passSound)
        or (eventDef and eventDef.fireSound)
        or "HTT_heli_pass_close"
    broadcastBombardSound(
        state,
        passSound,
        runtime.strikeX,
        runtime.strikeY,
        runtime.strikeZ,
        false
    )
end

local function ensurePendingStrikeFarFromPlayer(state)
    local player = resolveReferencePlayer(state)
    if not player then
        return
    end

    local minDist = HTT.toNumber(HTT.Config.BombardmentMinDistanceFromPlayer, 30)
    if minDist < 8 then
        minDist = 8
    end

    local dx = runtime.strikeX - player:getX()
    local dy = runtime.strikeY - player:getY()
    if (dx * dx + dy * dy) < (minDist * minDist) then
        local x, y, z = pickStrikePoint(state, player)
        setStrikePoint(state, x, y, z)
    end
end

local function explodePendingStrike(state, eventDef, now)
    ensurePendingStrikeFarFromPlayer(state)

    local explosionSound = (eventDef and eventDef.explosionSound)
        or (eventDef and eventDef.hitSound)
        or "HTT_explosion_far"
    broadcastBombardSound(
        state,
        explosionSound,
        runtime.strikeX,
        runtime.strikeY,
        runtime.strikeZ,
        {
            kind = "bombardment_explosion",
            text = tostring(HTT.Config.BombardmentIndicatorText or "BOOM"),
            duration = HTT.toNumber(HTT.Config.BombardmentIndicatorDurationSeconds, 5.0),
            r = 1.0,
            g = 0.34,
            b = 0.10,
        }
    )

    local killed, burned, candidates = applyStrikeDamage(runtime.strikeX, runtime.strikeY)
    HTT.log(string.format(
        "Air bombardment strike #%d at (%.1f, %.1f, %.1f) affected=%d killed=%d burned=%d",
        runtime.strikeCount + 1,
        runtime.strikeX,
        runtime.strikeY,
        runtime.strikeZ,
        candidates,
        killed,
        burned
    ))

    runtime.pendingExplosionHour = 0
    runtime.strikeCount = HTT.toNumber(runtime.strikeCount, 0) + 1

    local nextStrikeHour = now + getBombardmentStrikeIntervalHours()
    local latestPassStart = HTT.toNumber(state.endHour, now) - getBombardmentPassToExplosionHours()
    if nextStrikeHour > 0 and nextStrikeHour <= latestPassStart then
        runtime.strikeCompleted = false
        runtime.phase = "approach"
        runtime.nextStrikeHour = nextStrikeHour
        runtime.endEventHour = 0
        chooseNextStrikePoint(state)
        return
    end

    runtime.strikeCompleted = true
    runtime.phase = "fade"
    runtime.nextStrikeHour = 0
    runtime.endEventHour = now + getBombardmentPostExplosionEndHours()
end

local function bombardmentTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "air_bombardment" then
        resetRuntime()
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "nextStrikeHour", "pendingExplosionHour", "endEventHour" },
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

    local eventDef = HTT.getEventDefinition("air_bombardment")
    if not eventDef then
        return
    end

    initRuntimeIfNeeded(state, now)
    playApproachStartIfNeeded(state, eventDef)

    if runtime.strikeCompleted then
        if now >= HTT.toNumber(runtime.endEventHour, now) then
            if HTT.Server and HTT.Server.stopEvent then
                HTT.Server.stopEvent("bombardment-complete")
            end
        end
        return
    end

    local pending = HTT.toNumber(runtime.pendingExplosionHour, 0)
    if pending > 0 then
        if now >= pending then
            explodePendingStrike(state, eventDef, now)
        end
        return
    end

    local nextStrike = HTT.toNumber(runtime.nextStrikeHour, 0)
    if nextStrike > 0 and now >= nextStrike then
        startStrikePass(state, eventDef, now)
    end
end

local bombardTickHooked = registerEvent("OnTick", bombardmentTick)
if not bombardTickHooked then
    registerEvent("EveryOneMinute", bombardmentTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server air bombardment system loaded (hook=" .. tostring(bombardTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
