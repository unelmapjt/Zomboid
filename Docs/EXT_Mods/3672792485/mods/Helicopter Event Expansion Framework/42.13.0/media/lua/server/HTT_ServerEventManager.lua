require "HTT_Core"

HTT.Server = HTT.Server or {}
local Server = HTT.Server

if HTT._serverEventManagerLoaded then
    return
end
HTT._serverEventManagerLoaded = true

Server.state = Server.state or {
    active = false,
    eventId = nil,
    source = "none",
    startHour = 0,
    endHour = 0,
    centerX = 0,
    centerY = 0,
    centerZ = 0,
    radius = HTT.Config.DefaultToxicRadius,
    fadeMinutes = 0,
    toxicPhase = nil,
    toxicPhaseStartHour = 0,
    toxicPhaseEarliestHour = 0,
    toxicPhaseForceHour = 0,
    toxicNextAmbientHour = 0,
    followOnlineId = nil,
    supportNextBurstHour = 0,
    supportNextRotorHour = 0,
    hostilePhase = nil,
    hostilePhaseStartHour = 0,
    hostileNextRotorHour = 0,
    hostileNextVoiceHour = 0,
    hostileNextBurstHour = 0,
}
Server.state.supportNextBurstHour = HTT.toNumber(Server.state.supportNextBurstHour, 0)
Server.state.supportNextRotorHour = HTT.toNumber(Server.state.supportNextRotorHour, 0)
Server.state.hostilePhaseStartHour = HTT.toNumber(Server.state.hostilePhaseStartHour, 0)
Server.state.hostileNextRotorHour = HTT.toNumber(Server.state.hostileNextRotorHour, 0)
Server.state.hostileNextVoiceHour = HTT.toNumber(Server.state.hostileNextVoiceHour, 0)
Server.state.hostileNextBurstHour = HTT.toNumber(Server.state.hostileNextBurstHour, 0)
Server._soundSeq = HTT.toNumber(Server._soundSeq, 0)
Server._lastEventEndHour = HTT.toNumber(Server._lastEventEndHour, nil)
Server._autoNextAllowedHour = HTT.toNumber(Server._autoNextAllowedHour, nil)
Server._autoLastCooldownHours = HTT.toNumber(Server._autoLastCooldownHours, nil)
Server._lastAutoEventId = Server._lastAutoEventId ~= nil and tostring(Server._lastAutoEventId) or nil
Server._autoSchedulerStateLoaded = Server._autoSchedulerStateLoaded == true
Server._vanillaPauseActive = Server._vanillaPauseActive == true
Server._vanillaPauseLastHour = HTT.toNumber(Server._vanillaPauseLastHour, nil)
local MIN_AUTO_EVENT_COOLDOWN_HOURS = 6.0
local VANILLA_PAUSE_EPSILON_HOURS = 0.000001
local MIN_SUPPORT_START_DELAY_SECONDS = 4.0
local MIN_SUPPORT_ROTOR_REPEAT_SECONDS = 8.0
local MIN_HOSTILE_ROTOR_REPEAT_SECONDS = 8.0
local MIN_HOSTILE_VOICE_DELAY_SECONDS = 3.0
local TOXIC_PHASE_SOUND_VOLUME_MUL = 0.58
local SURVEILLANCE_MARK_KEY = "HTT_SurveillanceMarkedUntil"
local SURVEILLANCE_MARK_PRIORITY_CHANCE = 0.75
local FIXED_DAILY_AUTO_INTERVAL_HOURS = 24.0
local AUTO_EVENT_IDS = {
    "toxic",
    "support_attack",
    "hostile_attack",
    "air_bombardment",
    "downed_heli",
    "surveillance_event",
    "incendiary_sweep",
    "smoke_curtain_event",
    "electromagnetic_interference_event",
    "sniper_cover_event",
    "propaganda_broadcast_event",
    "fuel_reclamation_event",
    "military_vehicle_strike_event",
    "uav_scan_event",
}
local AUTO_SCHEDULER_STATE_KEY = "HTT_ServerAutoSchedulerState"
local AUTO_EVENT_PAUSE_STATE_HOUR_KEYS = {
    "endHour",
    "toxicPhaseStartHour",
    "toxicPhaseEarliestHour",
    "toxicPhaseForceHour",
    "toxicNextAmbientHour",
    "supportNextBurstHour",
    "supportNextRotorHour",
    "hostilePhaseStartHour",
    "hostileNextRotorHour",
    "hostileNextVoiceHour",
    "hostileNextBurstHour",
}

-- Server event modules also require this manager, so requiring them here creates
-- a circular load path and triggers LuaManager recursive require warnings.
-- Project Zomboid loads server scripts from media/lua/server on startup, and the
-- event modules still require this manager directly when they need its API.

local function getAutoSchedulerStateModData()
    if not ModData or not ModData.getOrCreate then
        return nil
    end

    local ok, md = pcall(function()
        return ModData.getOrCreate(AUTO_SCHEDULER_STATE_KEY)
    end)
    if not ok or not md then
        return nil
    end
    return md
end

local function persistAutoSchedulerState()
    local md = getAutoSchedulerStateModData()
    if not md then
        return false
    end

    md.autoNextAllowedHour = HTT.toNumber(Server._autoNextAllowedHour, nil)
    md.autoLastCooldownHours = HTT.toNumber(Server._autoLastCooldownHours, nil)
    md.lastEventEndHour = HTT.toNumber(Server._lastEventEndHour, nil)
    md.lastAutoEventId = Server._lastAutoEventId ~= nil and tostring(Server._lastAutoEventId) or nil

    if ModData and ModData.transmit then
        pcall(function()
            ModData.transmit(AUTO_SCHEDULER_STATE_KEY)
        end)
    end

    return true
end

local function restoreAutoSchedulerState(force)
    if Server._autoSchedulerStateLoaded == true and force ~= true then
        return true
    end

    local md = getAutoSchedulerStateModData()
    if not md then
        return false
    end

    Server._autoNextAllowedHour = HTT.toNumber(md.autoNextAllowedHour, Server._autoNextAllowedHour)
    Server._autoLastCooldownHours = HTT.toNumber(md.autoLastCooldownHours, Server._autoLastCooldownHours)
    Server._lastEventEndHour = HTT.toNumber(md.lastEventEndHour, Server._lastEventEndHour)

    if md.lastAutoEventId ~= nil then
        local restoredId = tostring(md.lastAutoEventId)
        if restoredId == "" then
            Server._lastAutoEventId = nil
        else
            Server._lastAutoEventId = restoredId
        end
    end

    Server._autoSchedulerStateLoaded = true
    return true
end

Server.persistAutoSchedulerState = persistAutoSchedulerState
Server.restoreAutoSchedulerState = restoreAutoSchedulerState

local function isUsablePlayer(player)
    if not player then
        return false
    end
    if player.isDead and player:isDead() then
        return false
    end
    if player.isAsleep then
        local ok, asleep = pcall(function()
            return player:isAsleep()
        end)
        if ok and asleep then
            return false
        end
    end
    if player.isSleeping then
        local ok, sleeping = pcall(function()
            return player:isSleeping()
        end)
        if ok and sleeping then
            return false
        end
    end
    return true
end

local function getOnlinePlayersList()
    if not getOnlinePlayers then
        return nil
    end
    return getOnlinePlayers()
end

local function pickFallbackLocalPlayer()
    if getPlayer then
        local p = getPlayer()
        if isUsablePlayer(p) then
            return p
        end
    end

    if getNumActivePlayers and getSpecificPlayer then
        local count = HTT.toNumber(getNumActivePlayers(), 0)
        for i = 0, count - 1 do
            local p = getSpecificPlayer(i)
            if isUsablePlayer(p) then
                return p
            end
        end
    end

    return nil
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

local function getCurrentWorldHourSafe()
    local gt = getGameTime and getGameTime() or nil
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return gt:getWorldAgeHours()
end

local function getVanillaHelicopterObject()
    if getWorld then
        local ok, world = pcall(getWorld)
        if ok and world and world.helicopter then
            return world.helicopter
        end
    end

    if IsoWorld and IsoWorld.instance and IsoWorld.instance.helicopter then
        return IsoWorld.instance.helicopter
    end

    return nil
end

local function shiftScheduledHours(target, keys, deltaHours)
    local delta = HTT.toNumber(deltaHours, 0)
    if not target or not keys or delta <= 0 then
        return 0
    end

    local changed = 0
    for i = 1, #keys do
        local key = keys[i]
        local value = HTT.toNumber(target[key], nil)
        if value ~= nil and value > 0 then
            target[key] = value + delta
            changed = changed + 1
        end
    end

    return changed
end

function Server.isVanillaHelicopterActive()
    local helicopter = getVanillaHelicopterObject()
    if not helicopter or not helicopter.isActive then
        return false
    end

    local ok, active = pcall(helicopter.isActive, helicopter)
    return ok and active == true
end

function Server.isPausedForVanilla()
    return Server._vanillaPauseActive == true
end

function Server.shouldPauseActiveEventForVanilla()
    local state = Server.state
    if not state or state.active ~= true then
        return false
    end

    return tostring(state.source or "") ~= "vanilla"
end

function Server.delayRuntimeHoursForVanillaPause(target, hourKeys, now)
    if not target or not hourKeys then
        return Server._vanillaPauseActive == true
    end

    if Server._vanillaPauseActive ~= true then
        target._httVanillaPauseLastHour = nil
        return false
    end

    local currentHour = HTT.toNumber(now, getCurrentWorldHourSafe())
    local lastHour = HTT.toNumber(target._httVanillaPauseLastHour, currentHour)
    local delta = math.max(0, currentHour - lastHour)
    if delta > VANILLA_PAUSE_EPSILON_HOURS then
        shiftScheduledHours(target, hourKeys, delta)
    end
    target._httVanillaPauseLastHour = currentHour
    return true
end

function Server.updateVanillaPauseState(now)
    local currentHour = HTT.toNumber(now, getCurrentWorldHourSafe())
    local vanillaActive = Server.isVanillaHelicopterActive()
    local pauseCurrentEvent = Server.shouldPauseActiveEventForVanilla and Server.shouldPauseActiveEventForVanilla() or false

    if vanillaActive then
        if Server._vanillaPauseActive ~= true then
            Server._vanillaPauseActive = true
            Server._vanillaPauseLastHour = currentHour
            if Server.state and Server.state.active and pauseCurrentEvent then
                HTT.log("HTT paused while vanilla helicopter event is active.")
            end
            return pauseCurrentEvent
        end

        local lastHour = HTT.toNumber(Server._vanillaPauseLastHour, currentHour)
        local delta = math.max(0, currentHour - lastHour)
        if delta > VANILLA_PAUSE_EPSILON_HOURS and Server.state and Server.state.active and pauseCurrentEvent then
            shiftScheduledHours(Server.state, AUTO_EVENT_PAUSE_STATE_HOUR_KEYS, delta)
        end
        Server._vanillaPauseLastHour = currentHour
        return pauseCurrentEvent
    end

    if Server._vanillaPauseActive == true then
        Server._vanillaPauseActive = false
        Server._vanillaPauseLastHour = nil
        if Server.state and Server.state.active and pauseCurrentEvent then
            HTT.log("HTT resumed after vanilla helicopter event ended.")
        end
    end

    return false
end

local function isPlayerMarkedBySurveillance(player, now)
    local md = getPlayerModDataSafe(player)
    if not md then
        return false
    end

    local markedUntil = HTT.toNumber(md[SURVEILLANCE_MARK_KEY], nil)
    if markedUntil == nil then
        return false
    end
    if markedUntil > HTT.toNumber(now, 0) then
        return true
    end

    md[SURVEILLANCE_MARK_KEY] = nil
    return false
end

local function pickRandomOnlinePlayer()
    local players = getOnlinePlayersList()
    if players and players:size() > 0 then
        local candidates = {}
        local markedCandidates = {}
        local now = getCurrentWorldHourSafe()
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if isUsablePlayer(p) then
                candidates[#candidates + 1] = p
                if isPlayerMarkedBySurveillance(p, now) then
                    markedCandidates[#markedCandidates + 1] = p
                end
            end
        end

        if #markedCandidates > 0 and ZombRandFloat(0, 1) <= SURVEILLANCE_MARK_PRIORITY_CHANCE then
            local markedIndex = ZombRand(#markedCandidates) + 1
            return markedCandidates[markedIndex]
        end

        if #candidates > 0 then
            local index = ZombRand(#candidates) + 1
            return candidates[index]
        end
    end

    return pickFallbackLocalPlayer()
end

local function hasDebugAccess(player)
    if not player then
        return false
    end

    local accessLevel = player:getAccessLevel()
    if not accessLevel then
        return false
    end

    accessLevel = string.lower(tostring(accessLevel))

    return accessLevel == "admin"
        or accessLevel == "moderator"
        or accessLevel == "gm"
        or accessLevel == "overseer"
end

local function sendDebugInfo(player, message)
    local args = { message = tostring(message or "") }

    if player then
        sendServerCommand(player, HTT.NET_MODULE, HTT.NET_COMMAND_DEBUG_INFO, args)
    else
        sendServerCommand(HTT.NET_MODULE, HTT.NET_COMMAND_DEBUG_INFO, args)
    end
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

local function hasLocalClientBridge()
    if getPlayer then
        local player = getPlayer()
        if player then
            return true
        end
    end

    if getNumActivePlayers and getSpecificPlayer then
        local count = HTT.toNumber(getNumActivePlayers(), 0)
        for i = 0, count - 1 do
            if getSpecificPlayer(i) then
                return true
            end
        end
    end

    return false
end

local function applyLocalClientCommand(command, args)
    if not hasLocalClientBridge() then
        return false
    end

    if command == HTT.NET_COMMAND_EVENT then
        if HTT.ApplyEventState then
            HTT.ApplyEventState(args)
            return true
        end
        return false
    end

    if command == HTT.NET_COMMAND_SOUND then
        if HTT.ApplySoundCommand then
            HTT.ApplySoundCommand(args)
            return true
        end
        if HTT.ClientPlaySoundNearPlayer then
            HTT.ClientPlaySoundNearPlayer(args)
            return true
        end
        return false
    end

    if command == HTT.NET_COMMAND_DEBUG_INFO and HTT.ApplyDebugInfo then
        HTT.ApplyDebugInfo(args)
        return true
    end

    return false
end

local function sendStateToPlayer(player)
    if not player then
        return
    end

    local args = {
        active = Server.state.active,
        eventId = Server.state.eventId,
        source = Server.state.source,
        startHour = Server.state.startHour,
        endHour = Server.state.endHour,
        centerX = Server.state.centerX,
        centerY = Server.state.centerY,
        centerZ = Server.state.centerZ,
        radius = Server.state.radius,
        fadeMinutes = Server.state.fadeMinutes,
        toxicPhase = Server.state.toxicPhase,
        toxicPhaseStartHour = Server.state.toxicPhaseStartHour,
        toxicPhaseEarliestHour = Server.state.toxicPhaseEarliestHour,
        toxicPhaseForceHour = Server.state.toxicPhaseForceHour,
        toxicNextAmbientHour = Server.state.toxicNextAmbientHour,
        followOnlineId = Server.state.followOnlineId,
        supportNextBurstHour = Server.state.supportNextBurstHour,
        supportNextRotorHour = Server.state.supportNextRotorHour,
        hostilePhase = Server.state.hostilePhase,
        hostilePhaseStartHour = Server.state.hostilePhaseStartHour,
        hostileNextRotorHour = Server.state.hostileNextRotorHour,
        hostileNextVoiceHour = Server.state.hostileNextVoiceHour,
        hostileNextBurstHour = Server.state.hostileNextBurstHour,
    }

    sendServerCommand(player, HTT.NET_MODULE, HTT.NET_COMMAND_EVENT, args)
end

function Server.broadcastEventState()
    local state = Server.state

    local args = {
        active = state.active,
        eventId = state.eventId,
        source = state.source,
        startHour = state.startHour,
        endHour = state.endHour,
        centerX = state.centerX,
        centerY = state.centerY,
        centerZ = state.centerZ,
        radius = state.radius,
        fadeMinutes = state.fadeMinutes,
        toxicPhase = state.toxicPhase,
        toxicPhaseStartHour = state.toxicPhaseStartHour,
        toxicPhaseEarliestHour = state.toxicPhaseEarliestHour,
        toxicPhaseForceHour = state.toxicPhaseForceHour,
        toxicNextAmbientHour = state.toxicNextAmbientHour,
        followOnlineId = state.followOnlineId,
        supportNextBurstHour = state.supportNextBurstHour,
        supportNextRotorHour = state.supportNextRotorHour,
        hostilePhase = state.hostilePhase,
        hostilePhaseStartHour = state.hostilePhaseStartHour,
        hostileNextRotorHour = state.hostileNextRotorHour,
        hostileNextVoiceHour = state.hostileNextVoiceHour,
        hostileNextBurstHour = state.hostileNextBurstHour,
    }

    sendServerCommand(HTT.NET_MODULE, HTT.NET_COMMAND_EVENT, args)
    applyLocalClientCommand(HTT.NET_COMMAND_EVENT, args)
end

function Server.broadcastSound(soundName, x, y, z, radius, extraArgs)
    if not soundName or soundName == "" then
        return false, "Missing sound id"
    end

    local args = {
        sound = tostring(soundName),
        x = HTT.toNumber(x, 0),
        y = HTT.toNumber(y, 0),
        z = HTT.toNumber(z, 0),
        radius = HTT.toNumber(radius, HTT.Config.DefaultSoundRadius),
    }

    if type(extraArgs) == "table" then
        for k, v in pairs(extraArgs) do
            args[k] = v
        end
    end

    if args.preferLocalPlayerSound == nil then
        local eventId = tostring(args.eventId or "")
        local eventDef = eventId ~= ""
            and HTT.getEventDefinition
            and HTT.getEventDefinition(eventId)
            or nil
        local soundText = tostring(soundName or "")
        local isPlayerAnchoredSound = args.attachToFollowPlayer == true or args.attachToLocalPlayer == true
        local isEventPresenceOrActionSound = eventDef
            and (
                soundText == tostring(eventDef.startSound or "")
                or soundText == tostring(eventDef.approachSound or "")
                or soundText == tostring(eventDef.activeSound or "")
                or soundText == tostring(eventDef.loopSound or "")
                or soundText == tostring(eventDef.collapseSound or "")
                or soundText == tostring(eventDef.passSound or "")
                or soundText == tostring(eventDef.impactSound or "")
                or soundText == tostring(eventDef.explosionSound or "")
                or soundText == tostring(eventDef.actionSound or "")
                or soundText == tostring(eventDef.voiceSound or "")
                or soundText == tostring(eventDef.fireSound or "")
                or soundText == tostring(eventDef.endSound or "")
            )
        if isPlayerAnchoredSound or isEventPresenceOrActionSound then
            args.preferLocalPlayerSound = true
        end
    end

    Server._soundSeq = HTT.toNumber(Server._soundSeq, 0) + 1
    if Server._soundSeq >= 2147483000 then
        Server._soundSeq = 1
    end
    args.sid = Server._soundSeq

    if sendServerCommand then
        sendServerCommand(HTT.NET_MODULE, HTT.NET_COMMAND_SOUND, args)
    end

    if applyLocalClientCommand(HTT.NET_COMMAND_SOUND, args) then
        return true
    end

    local inClient = isClient and isClient() or false
    local inServer = isServer and isServer() or false
    if not inClient and not inServer then
        if HTT.ApplySoundCommand then
            HTT.ApplySoundCommand(args)
        elseif HTT.ClientPlaySoundNearPlayer then
            HTT.ClientPlaySoundNearPlayer(args)
        end
    end

    return true
end

local function resolveEventCenter(anchorPlayer, x, y, z)
    local followOnlineId = nil

    if anchorPlayer then
        if not isUsablePlayer(anchorPlayer) then
            return nil, nil, nil, nil
        end
        if anchorPlayer.getOnlineID then
            followOnlineId = anchorPlayer:getOnlineID()
        end
        return anchorPlayer:getX(), anchorPlayer:getY(), anchorPlayer:getZ(), followOnlineId
    end

    if x ~= nil and y ~= nil then
        return HTT.toNumber(x, 0), HTT.toNumber(y, 0), HTT.toNumber(z, 0), followOnlineId
    end

    local fallback = pickRandomOnlinePlayer()
    if fallback then
        if fallback.getOnlineID then
            followOnlineId = fallback:getOnlineID()
        end
        return fallback:getX(), fallback:getY(), fallback:getZ(), followOnlineId
    end

    return nil, nil, nil, nil
end

local function getWorldAgeHoursSafe()
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

local function getSupportStartDelayHours()
    local firstDelayMinutes = HTT.toNumber(HTT.Config.SupportAttackFirstBurstDelayMinutes, 0)
    if firstDelayMinutes < 0 then
        firstDelayMinutes = 0
    end

    local configuredDelay = firstDelayMinutes / 60.0
    local minimumDelay = secondsToWorldHoursSafe(
        MIN_SUPPORT_START_DELAY_SECONDS,
        MIN_SUPPORT_START_DELAY_SECONDS
    )
    return math.max(configuredDelay, minimumDelay)
end

local function getSupportRotorRepeatHours()
    local rotorRepeatMinutes = HTT.toNumber(HTT.Config.SupportAttackRotorRepeatMinutes, 1)
    if rotorRepeatMinutes <= 0 then
        rotorRepeatMinutes = 1
    end

    local configuredRepeat = rotorRepeatMinutes / 60.0
    local minimumRepeat = secondsToWorldHoursSafe(
        MIN_SUPPORT_ROTOR_REPEAT_SECONDS,
        MIN_SUPPORT_ROTOR_REPEAT_SECONDS
    )
    return math.max(configuredRepeat, minimumRepeat)
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

local function getHostileVoiceDelayHours()
    local voiceDelayMinutes = HTT.toNumber(HTT.Config.HostileAttackVoiceDelayMinutes, 0.10)
    if voiceDelayMinutes < 0 then
        voiceDelayMinutes = 0
    end

    local configuredDelay = voiceDelayMinutes / 60.0
    local minimumDelay = secondsToWorldHoursSafe(
        MIN_HOSTILE_VOICE_DELAY_SECONDS,
        MIN_HOSTILE_VOICE_DELAY_SECONDS
    )
    return math.max(configuredDelay, minimumDelay)
end

local function pickAutoCooldownHours()
    local configuredHours = HTT.normalizeEventCooldownHours(
        HTT.Config.EventCooldownHours,
        72.0,
        true
    )

    if HTT.Config.EnableRandomEventCooldown == true then
        local randomMaxHours = math.max(MIN_AUTO_EVENT_COOLDOWN_HOURS, configuredHours)
        local randomHours = ZombRandFloat(MIN_AUTO_EVENT_COOLDOWN_HOURS, randomMaxHours)
        randomHours = math.max(MIN_AUTO_EVENT_COOLDOWN_HOURS, math.min(randomMaxHours, randomHours))
        return randomHours
    end

    local fixedHours = configuredHours
    if fixedHours == nil then
        return nil
    end
    return fixedHours
end

local function isFixedDailyAutoScheduleEnabled()
    return HTT.Config.EnableFixedDailyEventHour == true
end

local function getFixedDailyAutoScheduleHour()
    local dailyHour = HTT.toNumber(HTT.Config.FixedDailyEventHour, 9.0)
    if dailyHour == nil then
        dailyHour = 9.0
    end
    return math.max(0.0, math.min(23.75, dailyHour))
end

local function computeNextFixedDailyScheduleHour(baseHour, includeCurrentHour)
    local startHour = HTT.toNumber(baseHour, getWorldAgeHoursSafe())
    local dailyHour = getFixedDailyAutoScheduleHour()
    local currentDay = math.floor(startHour / FIXED_DAILY_AUTO_INTERVAL_HOURS)
    local nextHour = (currentDay * FIXED_DAILY_AUTO_INTERVAL_HOURS) + dailyHour

    if startHour > nextHour or (includeCurrentHour ~= true and startHour >= nextHour) then
        nextHour = nextHour + FIXED_DAILY_AUTO_INTERVAL_HOURS
    end

    return nextHour
end

local function scheduleNextAutoEvent(baseHour, includeCurrentHour)
    local startHour = HTT.toNumber(baseHour, getWorldAgeHoursSafe())
    if isFixedDailyAutoScheduleEnabled() then
        Server._autoLastCooldownHours = FIXED_DAILY_AUTO_INTERVAL_HOURS
        Server._autoNextAllowedHour = computeNextFixedDailyScheduleHour(startHour, includeCurrentHour)
        persistAutoSchedulerState()
        return true
    end

    local cooldownHours = pickAutoCooldownHours()
    if not cooldownHours then
        Server._autoNextAllowedHour = nil
        Server._autoLastCooldownHours = nil
        persistAutoSchedulerState()
        return false
    end

    Server._autoLastCooldownHours = cooldownHours
    Server._autoNextAllowedHour = startHour + cooldownHours
    persistAutoSchedulerState()
    return true
end

local function ensureAutoSchedule()
    restoreAutoSchedulerState()
    if Server._autoNextAllowedHour ~= nil then
        return
    end
    scheduleNextAutoEvent(getWorldAgeHoursSafe(), true)
end

local function isAutoEventCandidateEnabled(eventId)
    local id = tostring(eventId or "")
    if id == "" then
        return false
    end
    if HTT.getEventDefinition and not HTT.getEventDefinition(id) then
        return false
    end
    if HTT.isEventEnabled and not HTT.isEventEnabled(id) then
        return false
    end
    return true
end

local function collectAutoEventCandidates(excludeId)
    local excluded = tostring(excludeId or "")
    local candidates = {}
    for i = 1, #AUTO_EVENT_IDS do
        local id = AUTO_EVENT_IDS[i]
        if id ~= excluded and isAutoEventCandidateEnabled(id) then
            candidates[#candidates + 1] = id
        end
    end
    return candidates
end

local function pickRandomAutoCandidate(excludeId)
    local candidates = collectAutoEventCandidates(excludeId)
    if #candidates <= 0 then
        return nil
    end
    local index = ZombRand(#candidates) + 1
    return candidates[index]
end

local function pickAutoEventId()
    local chosen = nil

    if HTT.pickWeightedVanillaEventId then
        chosen = HTT.pickWeightedVanillaEventId()
    end

    chosen = tostring(chosen or "")
    if not isAutoEventCandidateEnabled(chosen) then
        local defaultId = tostring(HTT.Config.DefaultEventId or "")
        if isAutoEventCandidateEnabled(defaultId) then
            chosen = defaultId
        else
            chosen = tostring(pickRandomAutoCandidate(nil) or defaultId)
        end
    end

    local lastAutoId = tostring(Server._lastAutoEventId or "")
    if chosen ~= "" and lastAutoId ~= "" and chosen == lastAutoId then
        local alternative = pickRandomAutoCandidate(lastAutoId)
        if alternative then
            chosen = alternative
        end
    end

    return chosen
end

local function tryStartAutoEvent(now)
    if HTT.isModEnabled and not HTT.isModEnabled() then
        return
    end

    if Server.state.active then
        return
    end

    if Server.state.eventId == "toxic" and HTT.toNumber(Server.state.fadeMinutes, 0) > 0 then
        return
    end

    if Server.isPausedForVanilla and Server.isPausedForVanilla() then
        return
    end

    ensureAutoSchedule()
    local nextAllowed = HTT.toNumber(Server._autoNextAllowedHour, nil)
    if nextAllowed == nil or now < nextAllowed then
        return
    end

    if HTT.shouldBlockEventsForSleep and HTT.shouldBlockEventsForSleep() then
        if isFixedDailyAutoScheduleEnabled() then
            scheduleNextAutoEvent(nextAllowed, false)
            HTT.log("Auto scheduler skipped fixed daily event: sleep/fast-forward guard active.")
        end
        return
    end

    local eventId = pickAutoEventId()
    local autoDuration = HTT.Config.DefaultEventDurationHours
    if eventId == "toxic" and HTT.getConfiguredEventDurationHours then
        autoDuration = HTT.getConfiguredEventDurationHours("toxic", HTT.Config.DefaultEventDurationHours)
    end

    local ok, err = Server.startEvent(
        eventId,
        "auto",
        autoDuration
    )

    if ok then
        Server._lastAutoEventId = eventId
        -- Next auto schedule is set when the event stops.
        Server._autoNextAllowedHour = nil
        persistAutoSchedulerState()
        return
    end

    if isFixedDailyAutoScheduleEnabled() then
        scheduleNextAutoEvent(nextAllowed, false)
        HTT.log("Auto scheduler skipped fixed daily event: " .. tostring(err))
        return
    end

    -- Retry in one in-game minute if start failed (no players, etc.).
    Server._autoNextAllowedHour = now + (1.0 / 60.0)
    persistAutoSchedulerState()
    HTT.log("Auto scheduler could not start event: " .. tostring(err))
end

function Server.startEvent(eventId, source, durationHours, anchorPlayer, x, y, z, forceRestart, radiusOverride)
    local state = Server.state
    local eventDef = HTT.getEventDefinition(eventId or HTT.Config.DefaultEventId)
    local sourceText = tostring(source or "custom")

    if HTT.isModEnabled and not HTT.isModEnabled() then
        return false, "HTT disabled in sandbox"
    end

    if not eventDef then
        return false, "Unknown event id: " .. tostring(eventId)
    end

    if sourceText == "auto" and HTT.shouldBlockEventsForSleep and HTT.shouldBlockEventsForSleep() then
        return false, "Sleep/fast-forward guard active"
    end

    if sourceText == "auto" and Server.isVanillaHelicopterActive and Server.isVanillaHelicopterActive() then
        return false, "Vanilla helicopter active"
    end

    if HTT.isEventEnabled and not HTT.isEventEnabled(eventDef.id) then
        return false, "Event disabled in sandbox: " .. tostring(eventDef.id)
    end

    if state.active then
        if forceRestart then
            Server.stopEvent("restart")
        else
            return false, "Another HTT event is already active"
        end
    end

    local now = getWorldAgeHoursSafe()

    local centerX, centerY, centerZ, followOnlineId = resolveEventCenter(anchorPlayer, x, y, z)
    if not centerX or not centerY then
        return false, "No available awake players to anchor event center"
    end

    local defaultDuration = HTT.toNumber(eventDef.durationHours, HTT.Config.DefaultEventDurationHours)
    if eventDef.id == "toxic" and HTT.getConfiguredEventDurationHours then
        defaultDuration = HTT.getConfiguredEventDurationHours(eventDef.id, defaultDuration)
    end

    local duration = HTT.toNumber(durationHours, defaultDuration)

    if duration <= 0 then
        duration = defaultDuration
    end

    state.active = true
    state.eventId = eventDef.id
    state.source = sourceText
    state.startHour = now
    state.endHour = now + duration
    state.centerX = centerX
    state.centerY = centerY
    state.centerZ = centerZ
    state.radius = HTT.toNumber(radiusOverride, eventDef.radius)
    state.radius = HTT.toNumber(state.radius, HTT.Config.DefaultToxicRadius)
    state.fadeMinutes = 0
    state.toxicPhase = nil
    state.toxicPhaseStartHour = 0
    state.toxicPhaseEarliestHour = 0
    state.toxicPhaseForceHour = 0
    state.toxicNextAmbientHour = 0
    state.followOnlineId = followOnlineId
    state.supportNextBurstHour = 0
    state.supportNextRotorHour = 0
    state.hostilePhase = nil
    state.hostilePhaseStartHour = 0
    state.hostileNextRotorHour = 0
    state.hostileNextVoiceHour = 0
    state.hostileNextBurstHour = 0

    if state.eventId == "toxic" then
        local minMinutes = HTT.toNumber(HTT.Config.ToxicApproachMinMinutes, 2)
        local maxMinutes = HTT.toNumber(HTT.Config.ToxicApproachMaxMinutes, 6)
        if maxMinutes < minMinutes then
            maxMinutes = minMinutes
        end

        state.toxicPhase = "approach"
        state.toxicPhaseStartHour = now
        state.toxicPhaseEarliestHour = now + (minMinutes / 60)
        state.toxicPhaseForceHour = now + (maxMinutes / 60)
        state.toxicNextAmbientHour = 0
    elseif state.eventId == "support_attack" then
        state.supportNextBurstHour = now + getSupportStartDelayHours()
        -- Support rotor loop is owned by HTT_ServerSupport.lua to avoid stacked playback.
        state.supportNextRotorHour = now
    elseif state.eventId == "hostile_attack" then
        state.hostilePhase = "approach"
        state.hostilePhaseStartHour = now
        -- Hostile rotor loop is owned by HTT_ServerHostile.lua to avoid duplicate stacked playback.
        state.hostileNextRotorHour = now
        state.hostileNextVoiceHour = now + getHostileVoiceDelayHours()
        state.hostileNextBurstHour = 0
    end

    HTT.log(string.format(
        "Server event started id=%s source=%s duration=%.2f center=(%.1f, %.1f, %.1f) phase=%s",
        tostring(state.eventId),
        tostring(state.source),
        duration,
        state.centerX,
        state.centerY,
        state.centerZ,
        tostring(state.toxicPhase)
    ))

    Server.broadcastEventState()

    if state.eventId == "toxic" and addSound then
        addSound(
            nil,
            math.floor(state.centerX),
            math.floor(state.centerY),
            math.floor(state.centerZ),
            80,
            80
        )
    end

    if state.eventId == "toxic" then
        if eventDef.approachSound then
            local soundRadius = math.max(
                HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 80,
                HTT.Config.DefaultSoundRadius + 30
            )
            Server.broadcastSound(
                eventDef.approachSound,
                state.centerX,
                state.centerY,
                state.centerZ,
                soundRadius,
                {
                    volumeMul = TOXIC_PHASE_SOUND_VOLUME_MUL,
                    eventId = state.eventId,
                    attachToFollowPlayer = true,
                    followOnlineId = state.followOnlineId,
                }
            )
            HTT.log("Toxic phase sound approach broadcast radius=" .. tostring(soundRadius))
        end
    elseif state.eventId == "downed_heli" then
        -- Sequenced in HTT_ServerDownedHeli.lua: loop -> collapse -> impact.
    elseif state.eventId == "air_bombardment" then
        -- Sequenced in HTT_ServerBombardment.lua to keep pass/explosion staging clean.
    elseif state.eventId == "support_attack" then
        -- Support start rotor is emitted by HTT_ServerSupport.lua (single-source playback).
    elseif state.eventId == "hostile_attack" then
        -- Hostile start rotor is emitted by HTT_ServerHostile.lua (single-source playback).
    elseif eventDef.startSound then
        Server.broadcastSound(
            eventDef.startSound,
            state.centerX,
            state.centerY,
            state.centerZ,
            state.radius,
            {
                eventId = state.eventId,
                attachToFollowPlayer = true,
                followOnlineId = state.followOnlineId,
            }
        )
    end

    return true
end

function Server.stopEvent(reason)
    local state = Server.state

    if not state.active then
        return false, "No active event"
    end

    state.active = false
    state.endHour = getWorldAgeHoursSafe()
    Server._lastEventEndHour = state.endHour
    state.source = tostring(reason or "manual-stop")
    scheduleNextAutoEvent(state.endHour)

    if state.eventId == "toxic" then
        local toxicDef = HTT.getEventDefinition("toxic")
        if toxicDef and toxicDef.endSound then
            local soundRadius = math.max(
                HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 80,
                HTT.Config.DefaultSoundRadius + 30
            )
            Server.broadcastSound(
                toxicDef.endSound,
                state.centerX,
                state.centerY,
                state.centerZ,
                soundRadius,
                {
                    volumeMul = TOXIC_PHASE_SOUND_VOLUME_MUL,
                    eventId = state.eventId,
                    attachToFollowPlayer = true,
                    followOnlineId = state.followOnlineId,
                }
            )
            HTT.log("Toxic phase sound end broadcast radius=" .. tostring(soundRadius))
        end
        state.fadeMinutes = HTT.Config.ToxicFadeMinutes
        state.toxicPhase = "fade"
        state.toxicNextAmbientHour = 0
        state.supportNextBurstHour = 0
        state.supportNextRotorHour = 0
        state.hostilePhase = nil
        state.hostilePhaseStartHour = 0
        state.hostileNextRotorHour = 0
        state.hostileNextVoiceHour = 0
        state.hostileNextBurstHour = 0
    else
        state.fadeMinutes = 0
        state.supportNextBurstHour = 0
        state.supportNextRotorHour = 0
        state.hostilePhase = nil
        state.hostilePhaseStartHour = 0
        state.hostileNextRotorHour = 0
        state.hostileNextVoiceHour = 0
        state.hostileNextBurstHour = 0
        state.eventId = nil
        state.toxicPhase = nil
        state.toxicNextAmbientHour = 0
    end

    HTT.log(string.format(
        "Server event stopped id=%s reason=%s phase=%s",
        tostring(state.eventId),
        tostring(reason),
        tostring(state.toxicPhase)
    ))
    Server.broadcastEventState()

    return true
end

function Server.clearFinishedToxicFade()
    local state = Server.state
    if state.active then
        return
    end

    if state.eventId ~= "toxic" then
        return
    end

    if state.fadeMinutes > 0 then
        return
    end

    state.eventId = nil
    state.source = "none"
    state.toxicPhase = nil
    state.toxicPhaseStartHour = 0
    state.toxicPhaseEarliestHour = 0
    state.toxicPhaseForceHour = 0
    state.toxicNextAmbientHour = 0
    state.followOnlineId = nil
    state.supportNextBurstHour = 0
    state.supportNextRotorHour = 0
    state.hostilePhase = nil
    state.hostilePhaseStartHour = 0
    state.hostileNextRotorHour = 0
    state.hostileNextVoiceHour = 0
    state.hostileNextBurstHour = 0
    Server.broadcastEventState()
end

local function handleDebugCommand(player, args)
    args = args or {}

    if not hasDebugAccess(player) then
        sendDebugInfo(player, "HTT debug denied: admin/moderator required.")
        return
    end

    local action = tostring(args.action or "")

    if action == "startEvent" then
        local eventId = tostring(args.eventId or HTT.Config.DefaultEventId)
        local duration = HTT.toNumber(args.durationHours, nil)
        local radius = HTT.toNumber(args.radius, nil)
        local forceRestart = args.force == true

        local ok, err = Server.startEvent(
            eventId,
            "debug",
            duration,
            player,
            args.x,
            args.y,
            args.z,
            forceRestart,
            radius
        )

        if ok then
            sendDebugInfo(player, "HTT debug: event started (" .. eventId .. ")")
        else
            sendDebugInfo(player, "HTT debug: could not start event: " .. tostring(err))
        end
        return
    end

    if action == "stopEvent" then
        local ok, err = Server.stopEvent("debug-stop")
        if ok then
            sendDebugInfo(player, "HTT debug: event stopped")
        else
            sendDebugInfo(player, "HTT debug: " .. tostring(err))
        end
        return
    end

    if action == "playSound" then
        local soundName = tostring(args.sound or "")
        local x = HTT.toNumber(args.x, player and player:getX() or 0)
        local y = HTT.toNumber(args.y, player and player:getY() or 0)
        local z = HTT.toNumber(args.z, player and player:getZ() or 0)
        local radius = HTT.toNumber(args.radius, HTT.Config.DefaultSoundRadius)

        local ok, err = Server.broadcastSound(soundName, x, y, z, radius)
        if ok then
            sendDebugInfo(player, "HTT debug: sound played (" .. soundName .. ")")
        else
            sendDebugInfo(player, "HTT debug: could not play sound: " .. tostring(err))
        end
        return
    end

    if action == "setVanillaHook" then
        HTT.Config.EnableVanillaHelicopterHook = args.enabled == true
        sendDebugInfo(
            player,
            "HTT debug: vanilla hook = " .. tostring(HTT.Config.EnableVanillaHelicopterHook)
        )
        return
    end

    if action == "setPreset" then
        if not HTT.applyBalancePreset then
            sendDebugInfo(player, "HTT debug: preset system unavailable.")
            return
        end

        local requested = tostring(args.preset or "normal")
        local applied = HTT.applyBalancePreset(requested)
        sendDebugInfo(player, "HTT debug: preset applied = " .. tostring(applied))
        return
    end

    if action == "setToxicTick" then
        local seconds = HTT.toNumber(args.seconds, HTT.Config.ToxicTickSeconds)
        if not seconds then
            seconds = HTT.Config.ToxicTickSeconds
        end
        seconds = math.max(1, math.min(300, seconds))
        HTT.Config.ToxicTickSeconds = seconds
        sendDebugInfo(player, string.format("HTT debug: toxic tick = %.1fs", seconds))
        return
    end

    if action == "setToxicDamage" then
        sendDebugInfo(player, "HTT debug: legacy toxic damage removed; use toxic presets/per-minute settings.")
        return
    end

    if action == "setVanillaChance" then
        local chance = HTT.toNumber(args.chance, HTT.Config.VanillaHookTriggerChance)
        if not chance then
            chance = HTT.Config.VanillaHookTriggerChance
        end
        chance = math.max(0, math.min(100, chance))
        HTT.Config.VanillaHookTriggerChance = chance
        sendDebugInfo(player, string.format("HTT debug: vanilla hook chance = %.1f%%", chance))
        return
    end

    if action == "setEventWeights" then
        local wT = HTT.toNumber(args.toxic, HTT.Config.EventWeightToxic)
        local wS = HTT.toNumber(args.support, HTT.Config.EventWeightSupportAttack)
        local wH = HTT.toNumber(args.hostile, HTT.Config.EventWeightHostileAttack)

        if not wT then
            wT = HTT.Config.EventWeightToxic
        end
        if not wS then
            wS = HTT.Config.EventWeightSupportAttack
        end
        if not wH then
            wH = HTT.Config.EventWeightHostileAttack
        end

        HTT.Config.EventWeightToxic = math.max(0, math.min(1000, wT))
        HTT.Config.EventWeightSupportAttack = math.max(0, math.min(1000, wS))
        HTT.Config.EventWeightHostileAttack = math.max(0, math.min(1000, wH))

        sendDebugInfo(player, string.format(
            "HTT debug: event weights (toxic/support/hostile) = %.0f/%.0f/%.0f",
            HTT.toNumber(HTT.Config.EventWeightToxic, 60),
            HTT.toNumber(HTT.Config.EventWeightSupportAttack, 30),
            HTT.toNumber(HTT.Config.EventWeightHostileAttack, 10)
        ))
        return
    end

    if action == "applySandbox" then
        if HTT.applySandboxOptions and HTT.applySandboxOptions() then
            sendDebugInfo(player, "HTT debug: sandbox options applied.")
        else
            sendDebugInfo(player, "HTT debug: no sandbox options found for HTT.")
        end
        return
    end

    if action == "status" then
        local state = Server.state
        sendDebugInfo(player, string.format(
            "HTT status active=%s event=%s phase=%s hphase=%s source=%s center=(%.1f,%.1f,%.1f) radius=%.1f fade=%.2f follow=%s nextBurst=%.2f nextRotor=%.2f hNextBurst=%.2f hNextRotor=%.2f hNextVoice=%.2f preset=%s toxicPreset=%s mod=%s randomCooldown=%s fixedDailyHour=%s dailyHour=%.2f nextAuto=%.2f toxicTick=%.1fs toxicDmgPerMin=%.3f toxicMinPerMin=%.3f toxicCurve=%.2f toxicExtra=%.3f toxicExpGain=%.3f vanillaChance=%.1f w(t/s/h)=(%.0f/%.0f/%.0f) en(t/s/h/b/c/v/i/m)=(%s/%s/%s/%s/%s/%s/%s/%s) incendiaryRisk=%s",
            tostring(state.active),
            tostring(state.eventId),
            tostring(state.toxicPhase),
            tostring(state.hostilePhase),
            tostring(state.source),
            HTT.toNumber(state.centerX, 0),
            HTT.toNumber(state.centerY, 0),
            HTT.toNumber(state.centerZ, 0),
            HTT.toNumber(state.radius, 0),
            HTT.toNumber(state.fadeMinutes, 0),
            tostring(state.followOnlineId),
            HTT.toNumber(state.supportNextBurstHour, 0),
            HTT.toNumber(state.supportNextRotorHour, 0),
            HTT.toNumber(state.hostileNextBurstHour, 0),
            HTT.toNumber(state.hostileNextRotorHour, 0),
            HTT.toNumber(state.hostileNextVoiceHour, 0),
            tostring(HTT.Config.BalancePreset),
            tostring(HTT.Config.ToxicDamagePreset),
            tostring(HTT.isModEnabled and HTT.isModEnabled()),
            tostring(HTT.Config.EnableRandomEventCooldown),
            tostring(HTT.Config.EnableFixedDailyEventHour),
            HTT.toNumber(HTT.Config.FixedDailyEventHour, 9.0),
            HTT.toNumber(Server._autoNextAllowedHour, -1),
            HTT.toNumber(HTT.Config.ToxicTickSeconds, 60),
            HTT.toNumber(HTT.Config.ToxicDamagePerMinuteAtFullExposure, 1.10),
            HTT.toNumber(HTT.Config.ToxicDamageMinPerMinute, 0.12),
            HTT.toNumber(HTT.Config.ToxicDamageCurvePower, 1.60),
            HTT.toNumber(HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure, 0.01),
            HTT.toNumber(HTT.Config.ToxicExposureGainPerMin, 0.14),
            HTT.toNumber(HTT.Config.VanillaHookTriggerChance, 100),
            HTT.toNumber(HTT.Config.EventWeightToxic, 60),
            HTT.toNumber(HTT.Config.EventWeightSupportAttack, 30),
            HTT.toNumber(HTT.Config.EventWeightHostileAttack, 10),
            tostring(HTT.Config.EnableEventToxic),
            tostring(HTT.Config.EnableEventSupportAttack),
            tostring(HTT.Config.EnableEventHostileAttack),
            tostring(HTT.Config.EnableEventAirBombardment),
            tostring(HTT.Config.EnableEventDownedHeli),
            tostring(HTT.Config.EnableEventSurveillanceEvent),
            tostring(HTT.Config.EnableEventIncendiarySweep),
            tostring(HTT.Config.EnableEventSmokeCurtainEvent),
            tostring(HTT.Config.EnableIncendiarySweepPlayerRisk)
        ))
        return
    end

    sendDebugInfo(player, "HTT debug: unknown action '" .. action .. "'")
end

registerEvent("OnClientCommand", function(module, command, player, args)
    if module ~= HTT.NET_MODULE then
        return
    end

    if command ~= HTT.NET_COMMAND_DEBUG then
        return
    end

    handleDebugCommand(player, args)
end)

registerEvent("EveryOneMinute", function()
    local state = Server.state

    local now = getWorldAgeHoursSafe()
    local pausedForVanilla = Server.updateVanillaPauseState and Server.updateVanillaPauseState(now) or false
    if state.active and not pausedForVanilla and now >= state.endHour then
        Server.stopEvent("duration-expired")
        now = getWorldAgeHoursSafe()
    end

    tryStartAutoEvent(now)
end)

local connectedHooked = registerEvent("OnPlayerConnect", function(player)
    sendStateToPlayer(player)
end)

local createPlayerHooked = false
if not connectedHooked then
    createPlayerHooked = registerEvent("OnCreatePlayer", function(_, playerObj)
        sendStateToPlayer(playerObj)
    end)
end

if not connectedHooked and not createPlayerHooked then
    HTT.log("No player-connect event hook available; late-join state sync may not happen.")
end

registerEvent("OnInitGlobalModData", function()
    restoreAutoSchedulerState(true)
end)

registerEvent("OnGameStart", function()
    restoreAutoSchedulerState(true)
    ensureAutoSchedule()

    local now = getWorldAgeHoursSafe()
    local nextAllowed = HTT.toNumber(Server._autoNextAllowedHour, nil)
    if isFixedDailyAutoScheduleEnabled() then
        if nextAllowed ~= nil and nextAllowed > now then
            HTT.log(string.format(
                "Server event manager loaded. Event start mode = fixed daily hour %.2f (next in %.2f h).",
                getFixedDailyAutoScheduleHour(),
                nextAllowed - now
            ))
        else
            HTT.log(string.format(
                "Server event manager loaded. Event start mode = fixed daily hour %.2f.",
                getFixedDailyAutoScheduleHour()
            ))
        end
    elseif nextAllowed ~= nil and nextAllowed > now then
        HTT.log(string.format(
            "Server event manager loaded. Event start mode = automatic interval (next in %.2f h).",
            nextAllowed - now
        ))
    else
        HTT.log("Server event manager loaded. Event start mode = automatic interval.")
    end
end)
