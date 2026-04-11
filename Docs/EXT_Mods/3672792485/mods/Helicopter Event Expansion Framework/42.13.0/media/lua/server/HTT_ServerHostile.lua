require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerHostile = HTT.ServerHostile or {}

if HTT._serverHostileLoaded then
    return
end
HTT._serverHostileLoaded = true

local nextCenterSyncHour = 0
local MIN_HOSTILE_ROTOR_REPEAT_SECONDS = 26.0
local MIN_HOSTILE_BURST_SECONDS = 6.0
local HOSTILE_VOICE_TO_FIRE_SECONDS = 1.2

local function getBodyPartCandidates()
    if not BodyPartType then
        return nil
    end

    return {
        BodyPartType.ForeArm_L,
        BodyPartType.ForeArm_R,
        BodyPartType.UpperArm_L,
        BodyPartType.UpperArm_R,
        BodyPartType.Hand_L,
        BodyPartType.Hand_R,
        BodyPartType.UpperLeg_L,
        BodyPartType.UpperLeg_R,
        BodyPartType.LowerLeg_L,
        BodyPartType.LowerLeg_R,
        BodyPartType.Foot_L,
        BodyPartType.Foot_R,
        BodyPartType.Torso_Upper,
        BodyPartType.Torso_Lower,
    }
end

local function isFracturePart(partType)
    if not BodyPartType or not partType then
        return false
    end

    return partType == BodyPartType.ForeArm_L
        or partType == BodyPartType.ForeArm_R
        or partType == BodyPartType.UpperArm_L
        or partType == BodyPartType.UpperArm_R
        or partType == BodyPartType.Hand_L
        or partType == BodyPartType.Hand_R
        or partType == BodyPartType.UpperLeg_L
        or partType == BodyPartType.UpperLeg_R
        or partType == BodyPartType.LowerLeg_L
        or partType == BodyPartType.LowerLeg_R
        or partType == BodyPartType.Foot_L
        or partType == BodyPartType.Foot_R
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

local function getHostileRotorRepeatHours()
    local rotorRepeatMinutes = HTT.toNumber(HTT.Config.HostileAttackRotorRepeatMinutes, 0.18)
    if rotorRepeatMinutes <= 0 then
        rotorRepeatMinutes = 0.18
    end

    local configuredRepeat = rotorRepeatMinutes / 60.0
    local minimumRepeat = secondsToWorldHoursSafe(
        MIN_HOSTILE_ROTOR_REPEAT_SECONDS,
        MIN_HOSTILE_ROTOR_REPEAT_SECONDS
    )
    return math.max(configuredRepeat, minimumRepeat)
end

local function getHostileVoiceToFireDelayHours()
    return secondsToWorldHoursSafe(
        HOSTILE_VOICE_TO_FIRE_SECONDS,
        HOSTILE_VOICE_TO_FIRE_SECONDS
    )
end

local function getHostileBurstIntervalHours()
    local burstMinutes = HTT.toNumber(HTT.Config.HostileAttackBurstMinutes, 0.55)
    if burstMinutes <= 0 then
        burstMinutes = 0.55
    end

    local configuredInterval = burstMinutes / 60.0
    local minimumInterval = secondsToWorldHoursSafe(
        MIN_HOSTILE_BURST_SECONDS,
        MIN_HOSTILE_BURST_SECONDS
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

local function updateDynamicCenter(state)
    if not state or not state.active or state.eventId ~= "hostile_attack" then
        return nil
    end

    local target = resolveFollowPlayer(state)
    if not target then
        return nil
    end

    local nx = target:getX()
    local ny = target:getY()
    local nz = target:getZ()
    local ox = HTT.toNumber(state.centerX, 0)
    local oy = HTT.toNumber(state.centerY, 0)
    local oz = HTT.toNumber(state.centerZ, 0)

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

    return target
end

local function getHostileSoundRadius(state)
    local base = HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius)
    return math.max(base + 35, HTT.Config.DefaultSoundRadius + 20)
end

local function broadcastHostileSound(state, soundName, radius, x, y, z, extraArgs)
    if not soundName or soundName == "" then
        return false
    end

    if not HTT.Server or not HTT.Server.broadcastSound then
        return false
    end

    local mergedArgs = nil
    if type(extraArgs) == "table" then
        mergedArgs = {}
        for k, v in pairs(extraArgs) do
            mergedArgs[k] = v
        end
    end

    mergedArgs = mergedArgs or {}
    mergedArgs.eventId = state and state.eventId or "hostile_attack"
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
        HTT.toNumber(radius, getHostileSoundRadius(state)),
        mergedArgs
    )
end

local function pickBodyPart(player)
    if not player or not player.getBodyDamage then
        return nil, nil
    end

    local bd = player:getBodyDamage()
    if not bd or not bd.getBodyPart then
        return nil, nil
    end

    local candidates = getBodyPartCandidates()
    if not candidates then
        return nil, nil
    end

    local count = #candidates
    if count <= 0 then
        return nil, nil
    end

    for _ = 1, count do
        local idx = ZombRand(count) + 1
        local partType = candidates[idx]
        if partType then
            local bodyPart = bd:getBodyPart(partType)
            if bodyPart then
                return partType, bodyPart
            end
        end
    end

    return nil, nil
end

local function addPanicAndStress(player, extraMul)
    if not player or not player.getStats then
        return
    end

    local stats = player:getStats()
    if not stats then
        return
    end

    local mul = HTT.toNumber(extraMul, 1)
    if mul <= 0 then
        return
    end

    local panicGain = HTT.toNumber(HTT.Config.HostileAttackPanicGain, 6) * mul
    local stressGain = HTT.toNumber(HTT.Config.HostileAttackStressGain, 0.025) * mul

    if CharacterStat and CharacterStat.PANIC and stats.add then
        stats:add(CharacterStat.PANIC, panicGain)
    elseif stats.getPanic and stats.setPanic then
        local panic = HTT.toNumber(stats:getPanic(), 0)
        stats:setPanic(math.min(100, panic + panicGain))
    end

    if CharacterStat and CharacterStat.STRESS and stats.add then
        stats:add(CharacterStat.STRESS, stressGain)
    elseif stats.getStress and stats.setStress then
        local stress = HTT.toNumber(stats:getStress(), 0)
        stats:setStress(math.min(1, stress + stressGain))
    end
end

local function isPlayerShelteredFromAir(player)
    if not player then
        return false
    end

    local vehicle = player.getVehicle and player:getVehicle() or nil
    if vehicle then
        return true
    end

    local square = player.getSquare and player:getSquare() or nil
    if not square then
        return false
    end

    if square.getRoom and square:getRoom() then
        return true
    end

    if square.isOutside and square:isOutside() == false then
        return true
    end

    return false
end

local function getHostileBurstHitChance()
    local hitChancePercent = HTT.normalizePercentValue and HTT.normalizePercentValue(
        HTT.Config.HostileAttackHitChance,
        32,
        1
    ) or 32
    return hitChancePercent / 100.0
end

local function applyHostileHit(player, state, now)
    if not player or player:isDead() then
        return false
    end

    now = HTT.toNumber(now, getGameTime() and getGameTime():getWorldAgeHours() or 0)

    local px = player:getX()
    local py = player:getY()
    local radius = HTT.toNumber(HTT.Config.HostileAttackPlayerRadius, 18)
    local dx = px - HTT.toNumber(state.centerX, px)
    local dy = py - HTT.toNumber(state.centerY, py)
    if (dx * dx + dy * dy) > (radius * radius) then
        return false
    end

    local isSheltered = isPlayerShelteredFromAir(player)
    if isSheltered and HTT.Config.HostileAttackIndoorProtection ~= false then
        addPanicAndStress(player, 0.20)
        return false
    end

    local indoorHitMul = 1.0
    local indoorDamageMul = 1.0
    local indoorInjuryMul = 1.0
    if isSheltered then
        indoorHitMul = HTT.toNumber(HTT.Config.HostileAttackIndoorHitChanceMultiplier, 0.45)
        indoorDamageMul = HTT.toNumber(HTT.Config.HostileAttackIndoorDamageMultiplier, 0.35)
        indoorInjuryMul = HTT.toNumber(HTT.Config.HostileAttackIndoorInjuryChanceMultiplier, 0.50)
        if indoorHitMul < 0 then
            indoorHitMul = 0
        end
        if indoorDamageMul < 0 then
            indoorDamageMul = 0
        end
        if indoorInjuryMul < 0 then
            indoorInjuryMul = 0
        end
    end

    addPanicAndStress(player, 0.65)

    -- Hostile accuracy is rolled once per burst, not per bullet in the sound clip.
    local hitChance = getHostileBurstHitChance()
    hitChance = hitChance * indoorHitMul
    if ZombRandFloat(0, 1) > hitChance then
        return false
    end

    local bd = player:getBodyDamage()
    if not bd then
        return false
    end

    local partType, bodyPart = pickBodyPart(player)
    if not bodyPart then
        return false
    end

    if bodyPart.setHaveBullet then
        bodyPart:setHaveBullet(true, 0)
    end

    local lacerationChance = HTT.toNumber(HTT.Config.HostileAttackLacerationChance, 0.55) * indoorInjuryMul
    if ZombRandFloat(0, 1) <= lacerationChance then
        if bodyPart.setCut then
            bodyPart:setCut(true)
        end
    elseif bodyPart.setScratched then
        bodyPart:setScratched(true, false)
    end

    local fracChance = HTT.toNumber(HTT.Config.HostileAttackFractureChance, 0.16) * indoorInjuryMul
    if isFracturePart(partType) and bodyPart.getFractureTime and bodyPart.setFractureTime then
        if bodyPart:getFractureTime() <= 0 and ZombRandFloat(0, 1) <= fracChance then
            local minDays = math.floor(HTT.toNumber(HTT.Config.HostileAttackFractureMinDays, 10))
            local maxDays = math.floor(HTT.toNumber(HTT.Config.HostileAttackFractureMaxDays, 21))
            if maxDays < minDays then
                maxDays = minDays
            end
            local days = minDays + ZombRand((maxDays - minDays) + 1)
            bodyPart:setFractureTime(days)
        end
    end

    if player.addBlood and BloodBodyPartType and BodyPartType and partType then
        local bloodPart = BloodBodyPartType.FromIndex(BodyPartType.ToIndex(partType))
        if bloodPart then
            player:addBlood(bloodPart, false, true, false)
            if player.addHole then
                player:addHole(bloodPart)
            end
        end
    end

    local dmgMin = HTT.toNumber(HTT.Config.HostileAttackDamageMin, 0.12)
    local dmgMax = HTT.toNumber(HTT.Config.HostileAttackDamageMax, 0.45)
    if dmgMax < dmgMin then
        dmgMax = dmgMin
    end

    local minOverall = HTT.toNumber(HTT.Config.HostileAttackMinOverallHealth, 22)
    local overall = bd.getOverallBodyHealth and HTT.toNumber(bd:getOverallBodyHealth(), 100) or 100
    if overall > minOverall and bd.ReduceGeneralHealth then
        local rawDamage = ZombRandFloat(dmgMin, dmgMax) * indoorDamageMul
        local maxAllowed = math.max(0, overall - minOverall)
        local finalDamage = math.min(rawDamage, maxAllowed)
        if finalDamage > 0 then
            bd:ReduceGeneralHealth(finalDamage)
        end
    end

    if syncBodyPart then
        syncBodyPart(bodyPart, 0xFFFFFFFFFFF)
    end

    addPanicAndStress(player, 1.0)
    return true
end

local function playRotorLoopIfNeeded(state, now, eventDef)
    local nextRotorHour = HTT.toNumber(state.hostileNextRotorHour, 0)
    if nextRotorHour > 0 and now < nextRotorHour then
        return
    end

    state.hostileNextRotorHour = now + getHostileRotorRepeatHours()

    local rotorSound = eventDef and (eventDef.loopSound or eventDef.approachSound or eventDef.startSound) or nil
    broadcastHostileSound(state, rotorSound, getHostileSoundRadius(state))
end

local function updateHostilePhase(state, now, eventDef)
    if tostring(state.hostilePhase or "") ~= "approach" then
        return
    end

    local voiceHour = HTT.toNumber(state.hostileNextVoiceHour, 0)
    if voiceHour > 0 and now < voiceHour then
        return
    end

    state.hostilePhase = "active"
    state.hostilePhaseStartHour = now
    state.hostileNextBurstHour = now + getHostileVoiceToFireDelayHours()

    if HTT.Server and HTT.Server.broadcastEventState then
        HTT.Server.broadcastEventState()
    end

    local voiceSound = eventDef and eventDef.voiceSound or nil
    broadcastHostileSound(state, voiceSound, getHostileSoundRadius(state))
end

local function hostileBurst(state, eventDef, now)
    local target = resolveFollowPlayer(state)
    if not target then
        return
    end

    local fireSound = eventDef and eventDef.fireSound or nil
    local fired = broadcastHostileSound(
        state,
        fireSound,
        getHostileSoundRadius(state),
        target:getX(),
        target:getY(),
        target:getZ(),
        {
            eventId = "hostile_attack",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
    if not fired then
        HTT.log("Hostile burst sound skipped: fire sound missing or could not be dispatched")
    end

    local hitApplied = applyHostileHit(target, state, now)
    if not hitApplied then
        return
    end
end

local function hostileTick()
    if not HTT.Server or not HTT.Server.state then
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "hostile_attack" then
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

    local followUpdateSeconds = HTT.toNumber(HTT.Config.HostileAttackFollowUpdateSeconds, 0.75)
    if followUpdateSeconds <= 0 then
        followUpdateSeconds = 0.75
    end
    if nextCenterSyncHour <= 0 or now >= nextCenterSyncHour then
        updateDynamicCenter(state)
        nextCenterSyncHour = now + (followUpdateSeconds / 3600)
    end

    local eventDef = HTT.getEventDefinition("hostile_attack")
    if not eventDef then
        return
    end

    playRotorLoopIfNeeded(state, now, eventDef)
    updateHostilePhase(state, now, eventDef)

    if tostring(state.hostilePhase or "") ~= "active" then
        return
    end

    local nextBurstHour = HTT.toNumber(state.hostileNextBurstHour, 0)
    if nextBurstHour > 0 and now < nextBurstHour then
        return
    end

    hostileBurst(state, eventDef, now)
    state.hostileNextBurstHour = now + getHostileBurstIntervalHours()
end

local hostileTickHooked = registerEvent("OnTick", hostileTick)
if not hostileTickHooked then
    registerEvent("EveryOneMinute", hostileTick)
end

registerEvent("OnGameStart", function()
    HTT.log("Server hostile attack system loaded (hook=" .. tostring(hostileTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
