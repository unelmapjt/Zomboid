require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerSupport = HTT.ServerSupport or {}

if HTT._serverSupportLoaded then
    return
end
HTT._serverSupportLoaded = true
local nextCenterSyncHour = 0
local MIN_SUPPORT_START_DELAY_SECONDS = 4.0
local MIN_SUPPORT_ROTOR_REPEAT_SECONDS = 26.0
local MIN_SUPPORT_BURST_SECONDS = 6.0
local SUPPORT_PRIORITY_CLOSE_RADIUS = 10.0

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

local function getSupportStartDelayHours()
    local firstDelay = HTT.toNumber(HTT.Config.SupportAttackFirstBurstDelayMinutes, 0)
    if firstDelay < 0 then
        firstDelay = 0
    end

    local configuredDelay = firstDelay / 60.0
    local minimumDelay = secondsToWorldHoursSafe(
        MIN_SUPPORT_START_DELAY_SECONDS,
        MIN_SUPPORT_START_DELAY_SECONDS
    )
    return math.max(configuredDelay, minimumDelay)
end

local function getSupportRotorRepeatHours()
    local rotorRepeatMinutes = HTT.toNumber(HTT.Config.SupportAttackRotorRepeatMinutes, 0.16)
    if rotorRepeatMinutes <= 0 then
        rotorRepeatMinutes = 0.16
    end

    local configuredRepeat = rotorRepeatMinutes / 60.0
    local minimumRepeat = secondsToWorldHoursSafe(
        MIN_SUPPORT_ROTOR_REPEAT_SECONDS,
        MIN_SUPPORT_ROTOR_REPEAT_SECONDS
    )
    return math.max(configuredRepeat, minimumRepeat)
end

local function getSupportBurstIntervalHours()
    local burstMinutes = HTT.toNumber(HTT.Config.SupportAttackBurstMinutes, 0.20)
    if burstMinutes <= 0 then
        burstMinutes = 0.20
    end

    local configuredInterval = burstMinutes / 60.0
    local minimumInterval = secondsToWorldHoursSafe(
        MIN_SUPPORT_BURST_SECONDS,
        MIN_SUPPORT_BURST_SECONDS
    )
    return math.max(configuredInterval, minimumInterval)
end

local function resolveFollowPlayer(state)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        local target = nil
        local wantedId = state and state.followOnlineId or nil

        if wantedId ~= nil then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p and not p:isDead() and p.getOnlineID and p:getOnlineID() == wantedId then
                    target = p
                    break
                end
            end
        end

        if not target then
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
        end

        if target and target.getOnlineID then
            state.followOnlineId = target:getOnlineID()
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

local function updateDynamicCenter(state)
    if not state or not state.active or state.eventId ~= "support_attack" then
        return false
    end

    local target = resolveFollowPlayer(state)
    if not target then
        return false
    end

    local nx = target:getX()
    local ny = target:getY()
    local nz = target:getZ()
    local oldX = HTT.toNumber(state.centerX, 0)
    local oldY = HTT.toNumber(state.centerY, 0)
    local oldZ = HTT.toNumber(state.centerZ, 0)
    local moved = math.abs(nx - oldX) > 0.5
        or math.abs(ny - oldY) > 0.5
        or math.abs(nz - oldZ) > 0.1

    if not moved then
        return false
    end

    state.centerX = nx
    state.centerY = ny
    state.centerZ = nz

    if HTT.Server and HTT.Server.broadcastEventState then
        HTT.Server.broadcastEventState()
    end

    return true
end

local function pickBurstTargets(centerX, centerY, centerZ, radius, maxTargets, priorityX, priorityY, priorityZ)
    local cell = getCell()
    if not cell then
        return {}
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return {}
    end

    local limit = radius * radius
    local zLimit = 2
    local centerZNum = HTT.toNumber(centerZ, 0)
    local priorityXNum = HTT.toNumber(priorityX, centerX)
    local priorityYNum = HTT.toNumber(priorityY, centerY)
    local priorityZNum = HTT.toNumber(priorityZ, centerZNum)
    local candidates = {}
    local closeCandidates = {}
    local closeLimit = math.min(radius, SUPPORT_PRIORITY_CLOSE_RADIUS)
    local closeLimitSq = closeLimit * closeLimit
    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local zombieZ = HTT.toNumber(zombie:getZ(), 0)
            local dz = math.abs(zombieZ - centerZNum)
            local dx = zombie:getX() - centerX
            local dy = zombie:getY() - centerY
            local distSq = dx * dx + dy * dy
            if dz <= zLimit and distSq <= limit then
                local priorityDZ = math.abs(zombieZ - priorityZNum)
                local priorityDX = zombie:getX() - priorityXNum
                local priorityDY = zombie:getY() - priorityYNum
                local priorityDistSq = priorityDX * priorityDX + priorityDY * priorityDY
                candidates[#candidates + 1] = {
                    zombie = zombie,
                    score = (priorityDistSq * 0.9) + (distSq * 0.1) + (priorityDZ * 4.0),
                }
                if priorityDistSq <= closeLimitSq and priorityDZ <= 1.0 then
                    closeCandidates[#closeCandidates + 1] = candidates[#candidates]
                end
            end
        end
    end

    if #closeCandidates > 0 then
        candidates = closeCandidates
    elseif #candidates <= 0 then
        return {}
    end

    table.sort(candidates, function(left, right)
        return left.score < right.score
    end)

    local picked = {}
    local maxPickCount = math.min(#candidates, math.max(1, maxTargets))
    local pickCount = math.min(maxPickCount, math.max(1, ZombRand(maxPickCount) + 1))
    for i = 1, pickCount do
        picked[#picked + 1] = candidates[i].zombie
    end

    return picked
end

local function applyBurstDamage(zombie, damageMin, damageMax, executeThreshold, killer)
    if not zombie or zombie:isDead() then
        return false
    end

    local md = zombie:getModData()
    local current = HTT.toNumber(md.HTT_SupportVirtualHealth, nil)
    if current == nil or current <= 0 then
        current = 1.0
        md.HTT_SupportVirtualHealth = current
    end
    if current <= executeThreshold then
        return killZombieSafe(zombie, killer)
    end

    local dmg = ZombRandFloat(damageMin, damageMax)
    local nextHealth = current - dmg
    HTT.log(string.format(
        "Support burst zombie virtualHP=%.3f dmg=%.3f next=%.3f threshold=%.3f",
        current,
        dmg,
        nextHealth,
        executeThreshold
    ))
    md.HTT_SupportVirtualHealth = math.max(0, nextHealth)
    if nextHealth <= executeThreshold then
        local killed = killZombieSafe(zombie, killer)
        if killed then
            md.HTT_SupportVirtualHealth = nil
        end
        return killed
    end

    local appliedHealth = math.max(0.06, nextHealth)
    zombie:setHealth(appliedHealth)
    local bd = zombie.getBodyDamage and zombie:getBodyDamage() or nil
    if bd and bd.setOverallBodyHealth then
        pcall(function()
            bd:setOverallBodyHealth(appliedHealth * 100.0)
        end)
    end
    return zombie:isDead() or (zombie.isAlive and not zombie:isAlive()) or false
end

local function broadcastSupportSound(state, soundName, soundRadius, x, y, z, extraArgs)
    if not soundName or soundName == "" then
        return false
    end

    if not HTT.Server or not HTT.Server.broadcastSound then
        return false
    end

    local eventDef = HTT.getEventDefinition and HTT.getEventDefinition(state and state.eventId or "support_attack") or nil
    local mergedArgs = {}
    if type(extraArgs) == "table" then
        for k, v in pairs(extraArgs) do
            mergedArgs[k] = v
        end
    end

    mergedArgs.eventId = state and state.eventId or "support_attack"

    local hitSound = eventDef and tostring(eventDef.hitSound or "") or ""
    if soundName ~= hitSound then
        if mergedArgs.attachToFollowPlayer == nil then
            mergedArgs.attachToFollowPlayer = true
        end
        if mergedArgs.followOnlineId == nil then
            mergedArgs.followOnlineId = state and state.followOnlineId or nil
        end
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

local function playRotorLoopIfNeeded(state, now, eventDef)
    local nextRotorHour = HTT.toNumber(state.supportNextRotorHour, 0)
    if nextRotorHour > 0 and now < nextRotorHour then
        return
    end

    state.supportNextRotorHour = now + getSupportRotorRepeatHours()

    local rotorSound = eventDef and eventDef.startSound or nil
    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 35,
        HTT.Config.DefaultSoundRadius + 20
    )
    broadcastSupportSound(state, rotorSound, soundRadius)
end

local function runSupportBurst(state)
    local eventDef = HTT.getEventDefinition("support_attack")
    if not eventDef then
        return
    end

    local radius = HTT.toNumber(HTT.Config.SupportAttackZombieRadius, 28)
    if radius < 4 then
        radius = 4
    end

    local maxTargets = math.floor(HTT.toNumber(HTT.Config.SupportAttackMaxTargetsPerBurst, 3))
    if maxTargets < 1 then
        maxTargets = 1
    end
    if maxTargets > 3 then
        maxTargets = 3
    end

    local dmgMin = HTT.toNumber(HTT.Config.SupportAttackDamageMin, 0.35)
    local dmgMax = HTT.toNumber(HTT.Config.SupportAttackDamageMax, 1.10)
    if dmgMax < dmgMin then
        dmgMax = dmgMin
    end

    local executeThreshold = HTT.toNumber(HTT.Config.SupportAttackExecuteHealthThreshold, 0.35)
    if executeThreshold < 0 then
        executeThreshold = 0
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 35,
        HTT.Config.DefaultSoundRadius + 20
    )
    local fired = broadcastSupportSound(state, eventDef.fireSound, soundRadius)
    if not fired then
        HTT.log("Support burst skipped: fire sound missing or could not be dispatched")
        return
    end

    local supportTarget = resolveFollowPlayer(state)
    local targetX = supportTarget and supportTarget:getX() or state.centerX
    local targetY = supportTarget and supportTarget:getY() or state.centerY
    local targetZ = supportTarget and supportTarget:getZ() or state.centerZ
    local targets = pickBurstTargets(
        state.centerX,
        state.centerY,
        state.centerZ,
        radius,
        maxTargets,
        targetX,
        targetY,
        targetZ
    )
    if #targets <= 0 then
        HTT.log(string.format(
            "Support burst fired without targets center=(%.1f, %.1f)",
            HTT.toNumber(state.centerX, 0),
            HTT.toNumber(state.centerY, 0)
        ))
        return
    end

    local kills = 0
    local primaryTarget = targets[1]
    if primaryTarget and killZombieSafe(primaryTarget, supportTarget) then
        kills = kills + 1
    end

    for i = 1, #targets do
        local zombie = targets[i]
        if i > 1 and applyBurstDamage(zombie, dmgMin, dmgMax, executeThreshold, supportTarget) then
            kills = kills + 1
        end

        if zombie and eventDef.hitSound then
            local hitRadius = math.max(
                HTT.toNumber(HTT.Config.SupportAttackHitSoundRadius, 45),
                10
            )
            broadcastSupportSound(
                state,
                eventDef.hitSound,
                hitRadius,
                zombie:getX(),
                zombie:getY(),
                zombie:getZ(),
                { attachToFollowPlayer = false }
            )
        end
    end

    if kills <= 0 then
        if primaryTarget and not primaryTarget:isDead() and killZombieSafe(primaryTarget, supportTarget) then
            kills = kills + 1
        end
    end

    HTT.log(string.format(
        "Support burst applied targets=%d kills=%d center=(%.1f, %.1f)",
        #targets,
        kills,
        HTT.toNumber(state.centerX, 0),
        HTT.toNumber(state.centerY, 0)
    ))
end

local function supportTick()
    if not HTT.Server or not HTT.Server.state then
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "support_attack" then
        nextCenterSyncHour = 0
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        return
    end
    if now >= state.endHour then
        if HTT.Server and HTT.Server.stopEvent then
            HTT.Server.stopEvent("duration-expired")
        end
        nextCenterSyncHour = 0
        return
    end

    local followUpdateSeconds = HTT.toNumber(HTT.Config.SupportAttackFollowUpdateSeconds, 1.5)
    if followUpdateSeconds <= 0 then
        followUpdateSeconds = 1.5
    end
    if nextCenterSyncHour <= 0 or now >= nextCenterSyncHour then
        updateDynamicCenter(state)
        nextCenterSyncHour = now + (followUpdateSeconds / 3600)
    end

    local eventDef = HTT.getEventDefinition("support_attack")
    if not eventDef then
        return
    end

    playRotorLoopIfNeeded(state, now, eventDef)

    local nextBurstHour = HTT.toNumber(state.supportNextBurstHour, 0)
    if nextBurstHour <= 0 then
        state.supportNextBurstHour = now + getSupportStartDelayHours()
        return
    end

    if now < nextBurstHour then
        return
    end

    runSupportBurst(state)
    state.supportNextBurstHour = now + getSupportBurstIntervalHours()
end

local supportTickHooked = registerEvent("OnTick", supportTick)
if not supportTickHooked then
    registerEvent("EveryOneMinute", supportTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server support attack system loaded (hook=" .. tostring(supportTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
