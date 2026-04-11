require "HTT_Main"
require "HTT_ToxicEvent"
require "HTT_ClientNet"

HTT = HTT or {}

if HTT._clientDebugLoaded then
    return
end
HTT._clientDebugLoaded = true

HTT.DebugSounds = HTT.DebugSounds or {
    "HTT_bullet_impact_env",
    "HTT_aggressive_combat",
    "HTT_cough_01",
    "HTT_explosion_far",
    "HTT_explosion_impact",
    "HTT_hight_altitude_rotor",
    "HTT_heli_loop_far",
    "HTT_heli_pass_close",
    "HTT_hit_zombie",
    "HTT_hostile_fire_far",
    "HTT_human_voice_transmission",
    "HTT_loop_low_rotor",
    "HTT_loop_slowly_rotor",
    "HTT_loop_heavyfast_rotor",
    "HTT_loop_hovering_rotor",
    "HTT_loop_medium_rotor_distance",
    "HTT_loop_medium_rotor",
    "HTT_sensor_scan",
    "HTT_heavy_weapon",
    "HTT_hovering_low",
    "HTT_loop_tactical_rotor",
    "HTT_precision_rifle",
    "HTT_zombie_reaction_01",
    "HTT_zombie_reaction_02",
    "HTT_zombie_reaction_03",
    "HTT_loop_electromagnetic_interference",
    "HTT_electromagnetic_pulse_01",
    "HTT_electromagnetic_pulse_02",
    "HTT_loop_medium_broadcasting_rotor",
    "HTT_distorted_public_announcement_01",
    "HTT_distorted_public_announcement_02",
    "HTT_stable_hover_rotor",
    "HTT_fuel_extraction",
    "HTT_military_rotor",
    "HTT_aerial_strike",
    "HTT_uav_reconnaissance_rotor",
    "HTT_tactical_scan",
    "HTT_radio_static",
    "HTT_radio_voice_01",
    "HTT_structure_collapse_far",
    "HTT_toxic_ambient",
    "HTT_toxic_release",
}

HTT._spDebugState = HTT._spDebugState or {
    active = false,
    eventId = nil,
    source = "none",
    startHour = 0,
    endHour = 0,
    centerX = 0,
    centerY = 0,
    centerZ = 0,
    radius = HTT.Config.DefaultSoundRadius,
    fadeMinutes = 0,
    toxicPhase = nil,
    toxicPhaseStartHour = 0,
    toxicPhaseEarliestHour = 0,
    toxicPhaseForceHour = 0,
    toxicNextAmbientHour = 0,
    supportNextBurstHour = 0,
    supportNextRotorHour = 0,
    hostilePhase = nil,
    hostilePhaseStartHour = 0,
    hostileNextRotorHour = 0,
    hostileNextVoiceHour = 0,
    hostileNextBurstHour = 0,
}

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

local function isMPClient()
    return isClient and isClient()
end

local function getWorldAgeHoursSafe()
    if not getGameTime then
        return 0
    end

    local gt = getGameTime()
    if not gt or not gt.getWorldAgeHours then
        return 0
    end

    return gt:getWorldAgeHours()
end

local function getPlayerCoords()
    local player = getPlayer and getPlayer() or nil
    if player then
        return player:getX(), player:getY(), player:getZ()
    end

    local state = HTT._spDebugState
    return state.centerX, state.centerY, state.centerZ
end

local function buildStateArgs(state)
    return {
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
        supportNextBurstHour = state.supportNextBurstHour,
        supportNextRotorHour = state.supportNextRotorHour,
        hostilePhase = state.hostilePhase,
        hostilePhaseStartHour = state.hostilePhaseStartHour,
        hostileNextRotorHour = state.hostileNextRotorHour,
        hostileNextVoiceHour = state.hostileNextVoiceHour,
        hostileNextBurstHour = state.hostileNextBurstHour,
    }
end

local function applyEventStateLocal(args)
    if HTT.ApplyEventState then
        HTT.ApplyEventState(args)
        return
    end

    local previousState = HTT.serverEvent or {}
    local previousEventId = tostring(previousState.eventId or "")
    local nextEventId = tostring((args and args.eventId) or "")
    local wasSmokeActive = previousState.active == true and previousEventId == "smoke_curtain_event"
    local nowSmokeActive = args and args.active == true and nextEventId == "smoke_curtain_event"

    HTT.serverEvent = args
    HTT.active = args and args.active == true
    HTT.heliActive = HTT.active

    if wasSmokeActive and not nowSmokeActive and HTT.ClearSmokeCurtainFog then
        HTT.ClearSmokeCurtainFog("sp-local-sync")
    end
end

local function applySoundLocal(args)
    if HTT.ApplySoundCommand then
        HTT.ApplySoundCommand(args)
        return
    end

    HTT.ClientPlaySoundNearPlayer(args)
end

local function playStateSoundLocal(soundName, stateArgs, extraRadius)
    soundName = tostring(soundName or "")
    if soundName == "" then
        return
    end

    stateArgs = stateArgs or {}
    local radius = HTT.toNumber(stateArgs.radius, HTT.Config.DefaultSoundRadius)
    radius = radius + HTT.toNumber(extraRadius, 0)

    applySoundLocal({
        sound = soundName,
        x = HTT.toNumber(stateArgs.centerX, 0),
        y = HTT.toNumber(stateArgs.centerY, 0),
        z = HTT.toNumber(stateArgs.centerZ, 0),
        radius = radius,
    })
end

local function mirrorToxicPhaseSounds(prevArgs, currArgs)
    currArgs = currArgs or {}

    local eventId = tostring(currArgs.eventId or "")
    if eventId ~= "toxic" then
        return
    end

    local toxicDef = HTT.getEventDefinition("toxic")
    if not toxicDef then
        return
    end

    local currActive = currArgs.active == true
    local currPhase = tostring(currArgs.toxicPhase or "")
    local currFade = HTT.toNumber(currArgs.fadeMinutes, 0)

    local prevEventId = prevArgs and tostring(prevArgs.eventId or "") or ""
    local prevActive = prevArgs and prevArgs.active == true or false
    local prevPhase = prevArgs and tostring(prevArgs.toxicPhase or "") or ""
    local prevAmbientHour = HTT.toNumber(prevArgs and prevArgs.toxicNextAmbientHour or 0, 0)
    local currAmbientHour = HTT.toNumber(currArgs.toxicNextAmbientHour, 0)

    if currActive and currPhase == "approach" and (not prevActive or prevEventId ~= "toxic") then
        playStateSoundLocal(toxicDef.approachSound or toxicDef.startSound, currArgs, 80)
        return
    end

    if currActive and currPhase == "active" and prevPhase ~= "active" then
        playStateSoundLocal(toxicDef.activeSound or toxicDef.loopSound, currArgs, 80)
        return
    end

    if currActive
        and currPhase == "active"
        and prevPhase == "active"
        and currAmbientHour > 0
        and currAmbientHour ~= prevAmbientHour
    then
        playStateSoundLocal(toxicDef.activeSound or toxicDef.loopSound, currArgs, 80)
        return
    end

    if prevEventId == "toxic"
        and prevPhase ~= "fade"
        and (currPhase == "fade" or (not currActive and currFade > 0))
    then
        playStateSoundLocal(toxicDef.endSound, currArgs, 80)
    end
end

local function applyServerStateSyncLocal(args, mirrorSounds)
    local prevArgs = HTT._spServerLastEventArgs
    HTT._spServerLastEventArgs = args

    if mirrorSounds then
        mirrorToxicPhaseSounds(prevArgs, args)
    end

    applyEventStateLocal(args)
end

local function stopEventLocal(reason, silent)
    local state = HTT._spDebugState
    if not state.active then
        if not silent then
            HTT.log("Debug SP: no active event.")
        end
        return false
    end

    local stoppedEventId = state.eventId
    state.active = false
    state.source = tostring(reason or "sp-debug-stop")
    state.endHour = getWorldAgeHoursSafe()

    if stoppedEventId == "toxic" then
        state.fadeMinutes = HTT.Config.ToxicFadeMinutes
        state.toxicPhase = "fade"
        state.toxicPhaseStartHour = getWorldAgeHoursSafe()
        state.toxicNextAmbientHour = 0
        state.supportNextBurstHour = 0
        state.supportNextRotorHour = 0
        state.hostilePhase = nil
        state.hostilePhaseStartHour = 0
        state.hostileNextRotorHour = 0
        state.hostileNextVoiceHour = 0
        state.hostileNextBurstHour = 0

        local toxicDef = HTT.getEventDefinition("toxic")
        if toxicDef and toxicDef.endSound then
            playStateSoundLocal(toxicDef.endSound, state, 80)
        end
    else
        state.fadeMinutes = 0
        state.toxicPhase = nil
        state.toxicPhaseStartHour = 0
        state.toxicPhaseEarliestHour = 0
        state.toxicPhaseForceHour = 0
        state.toxicNextAmbientHour = 0
        state.supportNextBurstHour = 0
        state.supportNextRotorHour = 0
        state.hostilePhase = nil
        state.hostilePhaseStartHour = 0
        state.hostileNextRotorHour = 0
        state.hostileNextVoiceHour = 0
        state.hostileNextBurstHour = 0
    end

    applyEventStateLocal(buildStateArgs(state))

    if stoppedEventId ~= "toxic" then
        state.eventId = nil
        state.source = "none"
    end

    if not silent then
        HTT.log("Debug SP: event stopped (" .. tostring(stoppedEventId or "none") .. ")")
    end

    return true
end

local function startEventLocal(args)
    args = args or {}

    local state = HTT._spDebugState
    local eventId = tostring(args.eventId or HTT.Config.DefaultEventId)
    local eventDef = HTT.getEventDefinition(eventId)
    if not eventDef then
        HTT.log("Debug SP: unknown event id '" .. eventId .. "'")
        return false
    end
    if HTT.isEventEnabled and not HTT.isEventEnabled(eventDef.id) then
        HTT.log("Debug SP: event disabled in sandbox '" .. tostring(eventDef.id) .. "'")
        return false
    end

    local forceRestart = args.force == true
    if state.active then
        if forceRestart then
            stopEventLocal("sp-debug-restart", true)
        else
            HTT.log("Debug SP: another event is already active.")
            return false
        end
    end

    local now = getWorldAgeHoursSafe()
    local defaultDuration = HTT.toNumber(eventDef.durationHours, HTT.Config.DefaultEventDurationHours)
    if eventDef.id == "toxic" and HTT.getConfiguredEventDurationHours then
        defaultDuration = HTT.getConfiguredEventDurationHours(eventDef.id, defaultDuration)
    end

    local duration = HTT.toNumber(args.durationHours, defaultDuration)
    if duration <= 0 then
        duration = defaultDuration
    end

    local px, py, pz = getPlayerCoords()
    local x = HTT.toNumber(args.x, px)
    local y = HTT.toNumber(args.y, py)
    local z = HTT.toNumber(args.z, pz)
    local radius = HTT.toNumber(args.radius, eventDef.radius)
    radius = HTT.toNumber(radius, HTT.Config.DefaultSoundRadius)

    state.active = true
    state.eventId = eventId
    state.source = "sp-debug"
    state.startHour = now
    state.endHour = now + duration
    state.centerX = x
    state.centerY = y
    state.centerZ = z
    state.radius = radius
    state.fadeMinutes = 0
    state.toxicPhase = nil
    state.toxicPhaseStartHour = 0
    state.toxicPhaseEarliestHour = 0
    state.toxicPhaseForceHour = 0
    state.toxicNextAmbientHour = 0
    state.supportNextBurstHour = 0
    state.supportNextRotorHour = 0
    state.hostilePhase = nil
    state.hostilePhaseStartHour = 0
    state.hostileNextRotorHour = 0
    state.hostileNextVoiceHour = 0
    state.hostileNextBurstHour = 0

    if eventId == "toxic" then
        local minMinutes = HTT.toNumber(HTT.Config.ToxicApproachMinMinutes, 2)
        local maxMinutes = HTT.toNumber(HTT.Config.ToxicApproachMaxMinutes, 6)
        if maxMinutes < minMinutes then
            maxMinutes = minMinutes
        end

        state.toxicPhase = "approach"
        state.toxicPhaseStartHour = now
        state.toxicPhaseEarliestHour = now + (minMinutes / 60)
        state.toxicPhaseForceHour = now + (maxMinutes / 60)
    elseif eventId == "support_attack" then
        local firstDelay = HTT.toNumber(HTT.Config.SupportAttackFirstBurstDelayMinutes, 0)
        if firstDelay < 0 then
            firstDelay = 0
        end
        local rotorRepeat = HTT.toNumber(HTT.Config.SupportAttackRotorRepeatMinutes, 0.16)
        if rotorRepeat <= 0 then
            rotorRepeat = 0.16
        end
        state.supportNextBurstHour = now + (firstDelay / 60)
        state.supportNextRotorHour = now + (rotorRepeat / 60)
    elseif eventId == "hostile_attack" then
        local rotorRepeat = HTT.toNumber(HTT.Config.HostileAttackRotorRepeatMinutes, 0.18)
        if rotorRepeat <= 0 then
            rotorRepeat = 0.18
        end
        local voiceDelay = HTT.toNumber(HTT.Config.HostileAttackVoiceDelayMinutes, 0.10)
        if voiceDelay < 0 then
            voiceDelay = 0
        end
        state.hostilePhase = "approach"
        state.hostilePhaseStartHour = now
        state.hostileNextRotorHour = now + (rotorRepeat / 60)
        state.hostileNextVoiceHour = now + (voiceDelay / 60)
        state.hostileNextBurstHour = 0
    end

    applyEventStateLocal(buildStateArgs(state))

    local startSound = eventDef.startSound
    local startRadius = radius
    local startNoSquareSound = false
    local startNoWorldSound = false
    local startLocalOnly = false
    if eventId == "toxic" then
        startSound = eventDef.approachSound or eventDef.startSound
        startRadius = radius + 80
    end

    if startSound then
        applySoundLocal({
            sound = startSound,
            x = x,
            y = y,
            z = z,
            radius = startRadius,
            noSquareSound = startNoSquareSound,
            noWorldSound = startNoWorldSound,
            localOnly = startLocalOnly,
        })
    end

    HTT.log(string.format(
        "Debug SP: event started id=%s duration=%.2f radius=%.1f",
        eventId,
        duration,
        radius
    ))

    return true
end

local function playSoundLocal(args)
    args = args or {}

    local soundName = tostring(args.sound or "")
    if soundName == "" then
        HTT.log("Debug SP: missing sound id.")
        return false
    end

    local px, py, pz = getPlayerCoords()
    local radius = HTT.toNumber(args.radius, HTT.Config.DefaultSoundRadius)

    applySoundLocal({
        sound = soundName,
        x = HTT.toNumber(args.x, px),
        y = HTT.toNumber(args.y, py),
        z = HTT.toNumber(args.z, pz),
        radius = radius,
    })

    HTT.log("Debug SP: sound played (" .. soundName .. ")")
    return true
end

local function setVanillaHookLocal(args)
    args = args or {}
    HTT.Config.EnableVanillaHelicopterHook = args.enabled == true
    HTT.log("Debug SP: vanilla hook = " .. tostring(HTT.Config.EnableVanillaHelicopterHook))
    return true
end

local function setPresetLocal(args)
    args = args or {}
    if not HTT.applyBalancePreset then
        HTT.log("Debug SP: preset system unavailable.")
        return false
    end
    local preset = HTT.applyBalancePreset(tostring(args.preset or "normal"))
    HTT.log("Debug SP: preset applied = " .. tostring(preset))
    return true
end

local function setToxicTickLocal(args)
    args = args or {}
    local seconds = HTT.toNumber(args.seconds, HTT.Config.ToxicTickSeconds)
    if not seconds then
        seconds = HTT.Config.ToxicTickSeconds
    end
    HTT.Config.ToxicTickSeconds = math.max(1, math.min(300, seconds))
    HTT.log(string.format("Debug SP: toxic tick = %.1fs", HTT.toNumber(HTT.Config.ToxicTickSeconds, 60)))
    return true
end

local function setToxicDamageLocal(args)
    args = args or {}
    HTT.log("Debug SP: legacy toxic damage removed; use toxic presets/per-minute settings.")
    return true
end

local function setVanillaChanceLocal(args)
    args = args or {}
    local chance = HTT.toNumber(args.chance, HTT.Config.VanillaHookTriggerChance)
    if not chance then
        chance = HTT.Config.VanillaHookTriggerChance
    end
    HTT.Config.VanillaHookTriggerChance = math.max(0, math.min(100, chance))
    HTT.log(string.format("Debug SP: vanilla hook chance = %.1f%%", HTT.toNumber(HTT.Config.VanillaHookTriggerChance, 100)))
    return true
end

local function setEventWeightsLocal(args)
    args = args or {}
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

    HTT.log(string.format(
        "Debug SP: event weights (toxic/support/hostile) = %.0f/%.0f/%.0f",
        HTT.toNumber(HTT.Config.EventWeightToxic, 60),
        HTT.toNumber(HTT.Config.EventWeightSupportAttack, 30),
        HTT.toNumber(HTT.Config.EventWeightHostileAttack, 10)
    ))
    return true
end

local function applySandboxLocal()
    if HTT.applySandboxOptions and HTT.applySandboxOptions() then
        HTT.log("Debug SP: sandbox options applied.")
        return true
    end
    HTT.log("Debug SP: no sandbox options found for HTT.")
    return false
end

local function statusLocal()
    local state = HTT._spDebugState
    HTT.log(string.format(
            "Debug SP status active=%s event=%s phase=%s source=%s radius=%.1f endHour=%.2f preset=%s toxicPreset=%s mod=%s randomCooldown=%s toxicTick=%.1fs toxicDmgPerMin=%.3f toxicMinPerMin=%.3f toxicCurve=%.2f toxicExtra=%.3f toxicExpGain=%.3f vanillaChance=%.1f w(t/s/h)=(%.0f/%.0f/%.0f) en(t/s/h/b/c/v/i/m)=(%s/%s/%s/%s/%s/%s/%s/%s) incendiaryRisk=%s",
        tostring(state.active),
        tostring(state.eventId),
        tostring(state.toxicPhase),
        tostring(state.source),
        HTT.toNumber(state.radius, 0),
        HTT.toNumber(state.endHour, 0),
        tostring(HTT.Config.BalancePreset),
        tostring(HTT.Config.ToxicDamagePreset),
        tostring(HTT.isModEnabled and HTT.isModEnabled()),
        tostring(HTT.Config.EnableRandomEventCooldown),
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
    return true
end

local function sendDebugActionLocal(action, args)
    if action == "startEvent" then
        return startEventLocal(args)
    end
    if action == "stopEvent" then
        return stopEventLocal("sp-debug-stop", false)
    end
    if action == "playSound" then
        return playSoundLocal(args)
    end
    if action == "setVanillaHook" then
        return setVanillaHookLocal(args)
    end
    if action == "setPreset" then
        return setPresetLocal(args)
    end
    if action == "setToxicTick" then
        return setToxicTickLocal(args)
    end
    if action == "setToxicDamage" then
        return setToxicDamageLocal(args)
    end
    if action == "setVanillaChance" then
        return setVanillaChanceLocal(args)
    end
    if action == "setEventWeights" then
        return setEventWeightsLocal(args)
    end
    if action == "applySandbox" then
        return applySandboxLocal()
    end
    if action == "status" then
        return statusLocal()
    end

    HTT.log("Debug SP: unknown action '" .. tostring(action) .. "'")
    return false
end

local function syncFromServerState()
    if not HTT.Server or not HTT.Server.state then
        return
    end

    local args = buildStateArgs(HTT.Server.state)
    HTT._spServerSyncSig = table.concat({
        tostring(args.active),
        tostring(args.eventId),
        tostring(args.source),
        tostring(args.startHour),
        tostring(args.endHour),
        tostring(args.centerX),
        tostring(args.centerY),
        tostring(args.centerZ),
        tostring(args.radius),
        tostring(args.fadeMinutes),
        tostring(args.toxicPhase),
        tostring(args.toxicPhaseStartHour),
        tostring(args.toxicPhaseEarliestHour),
        tostring(args.toxicPhaseForceHour),
        tostring(args.toxicNextAmbientHour),
        tostring(args.supportNextBurstHour),
        tostring(args.supportNextRotorHour),
        tostring(args.hostilePhase),
        tostring(args.hostilePhaseStartHour),
        tostring(args.hostileNextBurstHour),
        tostring(args.hostileNextRotorHour),
        tostring(args.hostileNextVoiceHour),
    }, "|")

    applyServerStateSyncLocal(args, true)
end

local function sendDebugActionServerLocal(action, args)
    args = args or {}

    if not HTT.Server then
        return false
    end

    if action == "startEvent" and HTT.Server.startEvent then
        local eventId = tostring(args.eventId or HTT.Config.DefaultEventId)
        local duration = HTT.toNumber(args.durationHours, nil)
        local radius = HTT.toNumber(args.radius, nil)
        local forceRestart = args.force == true
        local player = getPlayer and getPlayer() or nil
        local x, y, z = getPlayerCoords()

        local ok, err = HTT.Server.startEvent(
            eventId,
            "sp-debug-server",
            duration,
            player,
            HTT.toNumber(args.x, x),
            HTT.toNumber(args.y, y),
            HTT.toNumber(args.z, z),
            forceRestart,
            radius
        )

        if ok then
            syncFromServerState()

            HTT.log("Debug SP(server): event started (" .. eventId .. ")")
        else
            HTT.log("Debug SP(server): could not start event: " .. tostring(err))
        end
        return ok == true
    end

    if action == "stopEvent" and HTT.Server.stopEvent then
        local ok, err = HTT.Server.stopEvent("sp-debug-server-stop")
        if ok then
            syncFromServerState()
            HTT.log("Debug SP(server): event stopped")
        else
            HTT.log("Debug SP(server): " .. tostring(err))
        end
        return ok == true
    end

    if action == "playSound" then
        local soundName = tostring(args.sound or "")
        local px, py, pz = getPlayerCoords()
        local soundArgs = {
            sound = soundName,
            x = HTT.toNumber(args.x, px),
            y = HTT.toNumber(args.y, py),
            z = HTT.toNumber(args.z, pz),
            radius = HTT.toNumber(args.radius, HTT.Config.DefaultSoundRadius),
        }

        local inClient = isClient and isClient() or false
        local inServer = isServer and isServer() or false
        local spLocal = not inClient and not inServer
        local playedByServerBroadcast = false

        if HTT.Server.broadcastSound then
            local ok = HTT.Server.broadcastSound(
                soundArgs.sound,
                soundArgs.x,
                soundArgs.y,
                soundArgs.z,
                soundArgs.radius
            )
            playedByServerBroadcast = ok == true and spLocal
        end

        if not playedByServerBroadcast then
            applySoundLocal(soundArgs)
        end

        HTT.log("Debug SP(server): sound played (" .. soundName .. ")")
        return true
    end

    if action == "setVanillaHook" then
        HTT.Config.EnableVanillaHelicopterHook = args.enabled == true
        HTT.log("Debug SP(server): vanilla hook = " .. tostring(HTT.Config.EnableVanillaHelicopterHook))
        return true
    end

    if action == "setPreset" then
        if not HTT.applyBalancePreset then
            HTT.log("Debug SP(server): preset system unavailable.")
            return false
        end
        local preset = HTT.applyBalancePreset(tostring(args.preset or "normal"))
        HTT.log("Debug SP(server): preset applied = " .. tostring(preset))
        return true
    end

    if action == "setToxicTick" then
        local seconds = HTT.toNumber(args.seconds, HTT.Config.ToxicTickSeconds)
        if not seconds then
            seconds = HTT.Config.ToxicTickSeconds
        end
        HTT.Config.ToxicTickSeconds = math.max(1, math.min(300, seconds))
        HTT.log(string.format("Debug SP(server): toxic tick = %.1fs", HTT.toNumber(HTT.Config.ToxicTickSeconds, 60)))
        return true
    end

    if action == "setToxicDamage" then
        HTT.log("Debug SP(server): legacy toxic damage removed; use toxic presets/per-minute settings.")
        return true
    end

    if action == "setVanillaChance" then
        local chance = HTT.toNumber(args.chance, HTT.Config.VanillaHookTriggerChance)
        if not chance then
            chance = HTT.Config.VanillaHookTriggerChance
        end
        HTT.Config.VanillaHookTriggerChance = math.max(0, math.min(100, chance))
        HTT.log(string.format("Debug SP(server): vanilla hook chance = %.1f%%", HTT.toNumber(HTT.Config.VanillaHookTriggerChance, 100)))
        return true
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

        HTT.log(string.format(
            "Debug SP(server): event weights (toxic/support/hostile) = %.0f/%.0f/%.0f",
            HTT.toNumber(HTT.Config.EventWeightToxic, 60),
            HTT.toNumber(HTT.Config.EventWeightSupportAttack, 30),
            HTT.toNumber(HTT.Config.EventWeightHostileAttack, 10)
        ))
        return true
    end

    if action == "applySandbox" then
        if HTT.applySandboxOptions and HTT.applySandboxOptions() then
            HTT.log("Debug SP(server): sandbox options applied.")
            return true
        end
        HTT.log("Debug SP(server): no sandbox options found for HTT.")
        return false
    end

    if action == "status" then
        local state = HTT.Server.state
        HTT.log(string.format(
            "Debug SP(server) status active=%s event=%s phase=%s hphase=%s source=%s center=(%.1f,%.1f,%.1f) radius=%.1f fade=%.2f follow=%s nextBurst=%.2f nextRotor=%.2f hNextBurst=%.2f hNextRotor=%.2f hNextVoice=%.2f preset=%s toxicPreset=%s mod=%s randomCooldown=%s toxicTick=%.1fs toxicDmgPerMin=%.3f toxicMinPerMin=%.3f toxicCurve=%.2f toxicExtra=%.3f toxicExpGain=%.3f vanillaChance=%.1f w(t/s/h)=(%.0f/%.0f/%.0f) en(t/s/h/b/c/v/i/m)=(%s/%s/%s/%s/%s/%s/%s/%s) incendiaryRisk=%s",
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
        return true
    end

    return false
end

local function sendDebugAction(action, args)
    args = args or {}
    args.action = action

    if isMPClient() then
        sendClientCommand(HTT.NET_MODULE, HTT.NET_COMMAND_DEBUG, args)
        return true
    end

    if sendDebugActionServerLocal(action, args) then
        return true
    end

    return sendDebugActionLocal(action, args)
end

local function stateSignatureFromArgs(args)
    args = args or {}
    return table.concat({
        tostring(args.active),
        tostring(args.eventId),
        tostring(args.source),
        tostring(args.startHour),
        tostring(args.endHour),
        tostring(args.centerX),
        tostring(args.centerY),
        tostring(args.centerZ),
        tostring(args.radius),
        tostring(args.fadeMinutes),
        tostring(args.toxicPhase),
        tostring(args.toxicPhaseStartHour),
        tostring(args.toxicPhaseEarliestHour),
        tostring(args.toxicPhaseForceHour),
        tostring(args.toxicNextAmbientHour),
        tostring(args.supportNextBurstHour),
        tostring(args.supportNextRotorHour),
        tostring(args.hostilePhase),
        tostring(args.hostilePhaseStartHour),
        tostring(args.hostileNextBurstHour),
        tostring(args.hostileNextRotorHour),
        tostring(args.hostileNextVoiceHour),
    }, "|")
end

function HTT.DebugStartEvent(eventId, durationHours, radius, forceRestart)
    return sendDebugAction("startEvent", {
        eventId = eventId or HTT.Config.DefaultEventId,
        durationHours = durationHours,
        radius = radius,
        force = forceRestart == true,
    })
end

function HTT.DebugStopEvent()
    return sendDebugAction("stopEvent", {})
end

function HTT.DebugPlaySound(soundName, radius)
    return sendDebugAction("playSound", {
        sound = soundName,
        radius = radius or HTT.Config.DefaultSoundRadius,
    })
end

function HTT.DebugPlaySoundLocal(soundName)
    return playSoundLocal({
        sound = soundName,
        radius = 0,
    })
end

function HTT.DebugSetVanillaHook(enabled)
    return sendDebugAction("setVanillaHook", {
        enabled = enabled == true,
    })
end

function HTT.DebugSetPreset(presetId)
    return sendDebugAction("setPreset", {
        preset = tostring(presetId or "normal"),
    })
end

function HTT.DebugApplySandbox()
    return sendDebugAction("applySandbox", {})
end

function HTT.DebugSetToxicTick(seconds)
    return sendDebugAction("setToxicTick", {
        seconds = seconds,
    })
end

function HTT.DebugSetToxicDamage(damagePerTick, maxExposureHealthDamage)
    local args = {
        damage = damagePerTick,
    }
    if maxExposureHealthDamage ~= nil then
        args.maxExposureHealthDamage = maxExposureHealthDamage
    end
    return sendDebugAction("setToxicDamage", args)
end

function HTT.DebugSetVanillaChance(chancePercent)
    return sendDebugAction("setVanillaChance", {
        chance = chancePercent,
    })
end

function HTT.DebugSetEventWeights(toxicWeight, supportWeight, hostileWeight)
    return sendDebugAction("setEventWeights", {
        toxic = toxicWeight,
        support = supportWeight,
        hostile = hostileWeight,
    })
end

function HTT.DebugStatus()
    return sendDebugAction("status", {})
end

function HTT.DebugSPStartEvent(eventId, durationHours, radius, forceRestart)
    return sendDebugAction("startEvent", {
        eventId = eventId or HTT.Config.DefaultEventId,
        durationHours = durationHours,
        radius = radius,
        force = forceRestart == true,
    })
end

function HTT.DebugSPStopEvent()
    return sendDebugAction("stopEvent", {})
end

function HTT.DebugSPPlaySound(soundName, radius)
    return sendDebugAction("playSound", {
        sound = soundName,
        radius = radius or HTT.Config.DefaultSoundRadius,
    })
end

function HTT.DebugSPStatus()
    return sendDebugAction("status", {})
end

function HTT.DebugListEvents()
    local ids = {}
    for id, _ in pairs(HTT.Events) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    HTT.log("HTT event ids: " .. table.concat(ids, ", "))
end

function HTT.DebugListSounds()
    HTT.log("HTT sounds: " .. table.concat(HTT.DebugSounds, ", "))
end

local function spDebugDurationTick()
    local state = HTT._spDebugState
    if not state.active then
        return
    end

    local now = getWorldAgeHoursSafe()
    if now >= state.endHour then
        stopEventLocal("sp-duration-expired", false)
    end
end

registerEvent("EveryOneMinute", spDebugDurationTick)

local function spServerSyncTick()
    if isMPClient() then
        return
    end

    if not HTT.Server or not HTT.Server.state then
        return
    end

    local args = buildStateArgs(HTT.Server.state)
    local sig = stateSignatureFromArgs(args)
    if HTT._spServerSyncSig == sig then
        return
    end

    HTT._spServerSyncSig = sig
    applyServerStateSyncLocal(args, true)
end

registerEvent("EveryOneMinute", spServerSyncTick)

function HTT.DebugHelp()
    HTT.log("MP/SP: HTT.DebugStartEvent(eventId, durationHours, radius, forceRestart)")
    HTT.log("      Ejemplo toxic:   HTT.DebugStartEvent(\"toxic\", 1.50, 20, true)")
    HTT.log("      Ejemplo support: HTT.DebugStartEvent(\"support_attack\", 0.35, 90, true)")
    HTT.log("      Ejemplo hostile: HTT.DebugStartEvent(\"hostile_attack\", 0.30, 90, true)")
    HTT.log("      Ejemplo bomb:    HTT.DebugStartEvent(\"air_bombardment\", 1.00, 120, true)")
    HTT.log("      Ejemplo crash:   HTT.DebugStartEvent(\"downed_heli\", 1.00, 120, true)")
    HTT.log("      Ejemplo surveil: HTT.DebugStartEvent(\"surveillance_event\", 0.90, 36, true)")
    HTT.log("      Ejemplo fire:    HTT.DebugStartEvent(\"incendiary_sweep\", 0.85, 120, true)")
    HTT.log("      Ejemplo smoke:   HTT.DebugStartEvent(\"smoke_curtain_event\", 0.90, 54, true)")
    HTT.log("      Ejemplo emi:     HTT.DebugStartEvent(\"electromagnetic_interference_event\", 0.75, 48, true)")
    HTT.log("      Ejemplo sniper:  HTT.DebugStartEvent(\"sniper_cover_event\", 0.70, 62, true)")
    HTT.log("      Ejemplo propaganda: HTT.DebugStartEvent(\"propaganda_broadcast_event\", 0.95, 72, true)")
    HTT.log("      Ejemplo fuel:    HTT.DebugStartEvent(\"fuel_reclamation_event\", 0.60, 76, true)")
    HTT.log("      Ejemplo mstrike: HTT.DebugStartEvent(\"military_vehicle_strike_event\", 0.55, 72, true)")
    HTT.log("      Ejemplo uav:     HTT.DebugStartEvent(\"uav_scan_event\", 0.80, 36, true)")
    HTT.log("Nota: para validar daño tóxico usa >= 1.00h; con 0.25h puede durar solo segundos según time scale.")
    HTT.log("MP/SP: HTT.DebugStopEvent()")
    HTT.log("MP/SP: HTT.DebugPlaySound(soundName, radius)")
    HTT.log("SP:    HTT.DebugSPStartEvent(eventId, durationHours, radius, forceRestart)")
    HTT.log("SP:    HTT.DebugSPStopEvent()")
    HTT.log("SP:    HTT.DebugSPPlaySound(soundName, radius)")
    HTT.log("SP:    HTT.DebugSPStatus()")
    HTT.log("Any:   HTT.DebugPlaySoundLocal(soundName)")
    HTT.log("Any:   HTT.DebugSetPreset(\"casual\"|\"normal\"|\"hardcore\")")
    HTT.log("Any:   HTT.DebugSetToxicTick(seconds)")
    HTT.log("Any:   HTT.DebugSetToxicDamage(damagePerTick, maxExposureHealthDamageOptional)")
    HTT.log("Any:   HTT.DebugSetVanillaChance(chancePercent)")
    HTT.log("Any:   HTT.DebugSetEventWeights(toxicWeight, supportWeight, hostileWeight)")
    HTT.log("Any:   HTT.DebugApplySandbox()")
    HTT.log("Any:   HTT.DebugStatus()")
    HTT.log("Sandbox keys: EnableMod/EnableRandomEventCooldown/EnableEventToxic/SupportAttack/HostileAttack/AirBombardment/DownedHeli/SurveillanceEvent/IncendiarySweep/EnableIncendiarySweepPlayerRisk/SmokeCurtainEvent/EMIInterference/SniperCover/PropagandaBroadcast/FuelReclamation/MilitaryVehicleStrike/UAVScan")
    HTT.log("Any:   HTT.DebugListEvents()")
    HTT.log("Any:   HTT.DebugListSounds()")
    HTT.log("Fog:     HTT.Config.ToxicFogIntensityApproach = 0.88")
    HTT.log("Fog:     HTT.Config.ToxicFogIntensityActive = 0.88")
    HTT.log("Support: HTT.Config.SupportAttackRotorRepeatMinutes = 0.16")
    HTT.log("Support: HTT.Config.SupportAttackBurstMinutes = 0.20")
    HTT.log("Support: HTT.Config.SupportAttackFirstBurstDelayMinutes = 0")
    HTT.log("Support: HTT.Config.SupportAttackDamageMin = 0.35 / Max = 1.10")
    HTT.log("Support: HTT.Config.SupportAttackMaxTargetsPerBurst = 3")
    HTT.log("Hostile: HTT.Config.HostileAttackVoiceDelayMinutes = 0.10")
    HTT.log("Hostile: HTT.Config.HostileAttackBurstMinutes = 0.55")
    HTT.log("Hostile: HTT.Config.HostileAttackHitChance = 32")
    HTT.log("Hostile: HTT.Config.HostileAttackHitCooldownMinutes = 1.25")
    HTT.log("Hostile: HTT.Config.HostileAttackMaxHitsPerEvent = 8")
    HTT.log("Hostile: HTT.Config.HostileAttackDamageMin = 0.12 / Max = 0.45")
    HTT.log("Hostile: HTT.Config.HostileAttackIndoorHitChanceMultiplier = 0.45")
    HTT.log("Hostile: HTT.Config.HostileAttackIndoorDamageMultiplier = 0.35")
    HTT.log("Hostile: HTT.Config.HostileAttackIndoorInjuryChanceMultiplier = 0.50")
    HTT.log("Hostile: HTT.Config.HostileAttackIndoorProtection = true")
    HTT.log("Events:  HTT.Config.DefaultEventDurationHours = 1.50")
    HTT.log("Events:  HTT.Config.ToxicEventDurationHours = 1.50")
    HTT.log("Events:  HTT.Config.EventCooldownHours = 72.00")
    HTT.log("Events:  HTT.Config.EnableRandomEventCooldown = false (aleatorio entre 6h y EventCooldownHours)")
    HTT.log("Client:  Ajustes de mods -> HTT Client -> Event sound volume (%)")
    HTT.log("Bomb:    HTT.Config.BombardmentRotorToPassSeconds = 45.0")
    HTT.log("Bomb:    HTT.Config.BombardmentFirstStrikeDelayMinutes = 0.12 (legacy fallback)")
    HTT.log("Bomb:    HTT.Config.BombardmentPassToExplosionSeconds = 2.0")
    HTT.log("Bomb:    HTT.Config.BombardmentStrikeIntervalMinutes = 0.55")
    HTT.log("Bomb:    HTT.Config.BombardmentMinDistanceFromPlayer = 30")
    HTT.log("Bomb:    HTT.Config.BombardmentInstantKillCount = 14")
    HTT.log("Bomb:    HTT.Config.BombardmentBurnTargetsPerStrike = 20")
    HTT.log("Bomb:    HTT.Config.BombardmentPostExplosionEndSeconds = 5.0")
    HTT.log("Bomb:    HTT.Config.BombardmentIndicatorText = \"BOOM\"")
    HTT.log("Bomb:    HTT.Config.EnableDirectionalSoundIndicator = true")
    HTT.log("Bomb:    HTT.Config.BombardmentIndicatorDurationSeconds = 5.0")
    HTT.log("Crash:   HTT.Config.DownedHeliApproachMinutes = 0.20")
    HTT.log("Crash:   HTT.Config.DownedHeliRotorToCollapseSeconds = 45.0")
    HTT.log("Crash:   HTT.Config.DownedHeliCollapseToImpactSeconds = 10.0")
    HTT.log("Crash:   HTT.Config.DownedHeliMinDistanceFromPlayer = 45")
    HTT.log("Crash:   HTT.Config.DownedHeliMaxDistanceFromPlayer = 95")
    HTT.log("Crash:   HTT.Config.DownedHeliAttractRadius = 150 / Volume = 150")
    HTT.log("Crash:   HTT.Config.DownedHeliAttractPulseCount = 5")
    HTT.log("Toxic:   HTT.Config.ToxicTickSeconds = 60")
    HTT.log("Toxic:   HTT.Config.ToxicIndoorProtection = true")
    HTT.log("Toxic:   HTT.Config.ToxicIndoorExposureMultiplier = 0.40")
    HTT.log("Toxic:   HTT.Config.ToxicDamagePerMinuteAtFullExposure = 1.10")
    HTT.log("Vanilla: HTT.Config.EnableVanillaHelicopterHook = true")
    HTT.log("Vanilla: HTT.Config.VanillaHookTriggerChance = 100")
    HTT.log("Vanilla: HTT.Config.UseVanillaRotorSoundsInEvents = false")
    HTT.log("Weights: HTT.Config.EventWeightToxic/SupportAttack/HostileAttack")
end

registerEvent("OnGameStart", function()
    HTT.log("Debug commands loaded. Run HTT.DebugHelp() in Lua console.")
end)
