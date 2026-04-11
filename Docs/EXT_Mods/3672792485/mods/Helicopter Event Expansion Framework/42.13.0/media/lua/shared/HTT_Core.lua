HTT = HTT or {}

HTT.NET_MODULE = HTT.NET_MODULE or "HTT"
HTT.NET_COMMAND_EVENT = HTT.NET_COMMAND_EVENT or "EventState"
HTT.NET_COMMAND_SOUND = HTT.NET_COMMAND_SOUND or "PlaySound"
HTT.NET_COMMAND_DEBUG = HTT.NET_COMMAND_DEBUG or "Debug"
HTT.NET_COMMAND_DEBUG_INFO = HTT.NET_COMMAND_DEBUG_INFO or "DebugInfo"

HTT.Config = HTT.Config or {}

function HTT.normalizePercentValue(value, fallback, minValue)
    local n = tonumber(value)
    if n == nil then
        n = tonumber(fallback)
    end
    if n == nil then
        n = tonumber(minValue) or 0
    end

    if n > 0 and n < 1 then
        n = n * 100.0
    end

    local minPercent = tonumber(minValue)
    if minPercent ~= nil and n < minPercent then
        n = minPercent
    end
    if n > 100.0 then
        n = 100.0
    end

    return math.floor(n + 0.5)
end

if HTT.Config.EnableVanillaHelicopterHook == nil then
    HTT.Config.EnableVanillaHelicopterHook = true
end

if HTT.Config.BalancePreset == nil then
    HTT.Config.BalancePreset = "normal"
end

if HTT.Config.ToxicDamagePreset == nil then
    HTT.Config.ToxicDamagePreset = "soft"
end

if HTT.Config.EnableMod == nil then
    HTT.Config.EnableMod = true
end

if HTT.Config.DefaultEventId == nil then
    HTT.Config.DefaultEventId = "toxic"
end

if HTT.Config.DefaultEventDurationHours == nil then
    HTT.Config.DefaultEventDurationHours = 1.5
end

if HTT.Config.ToxicEventDurationHours == nil then
    HTT.Config.ToxicEventDurationHours = HTT.Config.DefaultEventDurationHours
end

if HTT.Config.EventCooldownHours == nil then
    HTT.Config.EventCooldownHours = 72.0
end

if HTT.Config.EnableRandomEventCooldown == nil then
    HTT.Config.EnableRandomEventCooldown = false
end

if HTT.Config.EnableFixedDailyEventHour == nil then
    HTT.Config.EnableFixedDailyEventHour = false
end

if HTT.Config.FixedDailyEventHour == nil then
    HTT.Config.FixedDailyEventHour = 9.0
end

if HTT.Config.DisableEventsDuringSleep == nil then
    HTT.Config.DisableEventsDuringSleep = true
end

if HTT.Config.EventSoundVolumePercent == nil then
    HTT.Config.EventSoundVolumePercent = 100
end

if HTT.Config.UseVanillaRotorSoundsInEvents == nil then
    HTT.Config.UseVanillaRotorSoundsInEvents = false
end

if HTT.Config.VanillaRotorSoundId == nil then
    HTT.Config.VanillaRotorSoundId = "Helicopter"
end

if HTT.Config.DefaultSoundRadius == nil then
    HTT.Config.DefaultSoundRadius = 70
end

if HTT.Config.DefaultToxicRadius == nil then
    HTT.Config.DefaultToxicRadius = 15
end

if HTT.Config.ToxicFadeMinutes == nil then
    HTT.Config.ToxicFadeMinutes = 10
end

if HTT.Config.ToxicApproachMinMinutes == nil then
    HTT.Config.ToxicApproachMinMinutes = 2
end

if HTT.Config.ToxicApproachMaxMinutes == nil then
    HTT.Config.ToxicApproachMaxMinutes = 6
end

if HTT.Config.ToxicNearZombieRadius == nil then
    HTT.Config.ToxicNearZombieRadius = 26
end

if HTT.Config.ToxicNearZombieCount == nil then
    HTT.Config.ToxicNearZombieCount = 8
end

if HTT.Config.ToxicAmbientRepeatMinutes == nil then
    HTT.Config.ToxicAmbientRepeatMinutes = 2
end

if HTT.Config.EnableToxicFog == nil then
    HTT.Config.EnableToxicFog = true
end

if HTT.Config.ToxicFogIntensityApproach == nil then
    HTT.Config.ToxicFogIntensityApproach = 0.88
end

if HTT.Config.ToxicFogIntensityActive == nil then
    HTT.Config.ToxicFogIntensityActive = 0.88
end

if HTT.Config.ToxicFogSmoothing == nil then
    HTT.Config.ToxicFogSmoothing = 0.35
end

if HTT.Config.SupportAttackZombieRadius == nil then
    HTT.Config.SupportAttackZombieRadius = 28
end

if HTT.Config.SupportAttackBurstMinutes == nil then
    HTT.Config.SupportAttackBurstMinutes = 0.20
end

if HTT.Config.SupportAttackRotorRepeatMinutes == nil then
    HTT.Config.SupportAttackRotorRepeatMinutes = 0.16
end

if HTT.Config.SupportAttackFirstBurstDelayMinutes == nil then
    HTT.Config.SupportAttackFirstBurstDelayMinutes = 0
end

if HTT.Config.SupportAttackMaxTargetsPerBurst == nil then
    HTT.Config.SupportAttackMaxTargetsPerBurst = 3
end

if HTT.Config.SupportAttackDamageMin == nil then
    HTT.Config.SupportAttackDamageMin = 0.35
end

if HTT.Config.SupportAttackDamageMax == nil then
    HTT.Config.SupportAttackDamageMax = 1.10
end

if HTT.Config.SupportAttackExecuteHealthThreshold == nil then
    HTT.Config.SupportAttackExecuteHealthThreshold = 0.35
end

if HTT.Config.SupportAttackHitSoundRadius == nil then
    HTT.Config.SupportAttackHitSoundRadius = 45
end

if HTT.Config.SupportAttackFollowUpdateSeconds == nil then
    HTT.Config.SupportAttackFollowUpdateSeconds = 1.5
end

if HTT.Config.HostileAttackPlayerRadius == nil then
    HTT.Config.HostileAttackPlayerRadius = 18
end

if HTT.Config.HostileAttackBurstMinutes == nil then
    HTT.Config.HostileAttackBurstMinutes = 0.55
end

if HTT.Config.HostileAttackRotorRepeatMinutes == nil then
    HTT.Config.HostileAttackRotorRepeatMinutes = 0.18
end

if HTT.Config.HostileAttackVoiceDelayMinutes == nil then
    HTT.Config.HostileAttackVoiceDelayMinutes = 0.10
end

if HTT.Config.HostileAttackFollowUpdateSeconds == nil then
    HTT.Config.HostileAttackFollowUpdateSeconds = 0.75
end

if HTT.Config.HostileAttackHitChance == nil then
    HTT.Config.HostileAttackHitChance = 32
else
    HTT.Config.HostileAttackHitChance = HTT.normalizePercentValue(
        HTT.Config.HostileAttackHitChance,
        32,
        1
    )
end

if HTT.Config.HostileAttackHitCooldownMinutes == nil then
    HTT.Config.HostileAttackHitCooldownMinutes = 1.25
end

if HTT.Config.HostileAttackMaxHitsPerEvent == nil then
    HTT.Config.HostileAttackMaxHitsPerEvent = 8
end

if HTT.Config.HostileAttackDamageMin == nil then
    HTT.Config.HostileAttackDamageMin = 0.12
end

if HTT.Config.HostileAttackDamageMax == nil then
    HTT.Config.HostileAttackDamageMax = 0.45
end

if HTT.Config.HostileAttackPanicGain == nil then
    HTT.Config.HostileAttackPanicGain = 6
end

if HTT.Config.HostileAttackStressGain == nil then
    HTT.Config.HostileAttackStressGain = 0.025
end

if HTT.Config.HostileAttackLacerationChance == nil then
    HTT.Config.HostileAttackLacerationChance = 0.55
end

if HTT.Config.HostileAttackFractureChance == nil then
    HTT.Config.HostileAttackFractureChance = 0.16
end

if HTT.Config.HostileAttackFractureMinDays == nil then
    HTT.Config.HostileAttackFractureMinDays = 10
end

if HTT.Config.HostileAttackFractureMaxDays == nil then
    HTT.Config.HostileAttackFractureMaxDays = 21
end

if HTT.Config.HostileAttackMinOverallHealth == nil then
    HTT.Config.HostileAttackMinOverallHealth = 22
end

if HTT.Config.HostileAttackIndoorHitChanceMultiplier == nil then
    HTT.Config.HostileAttackIndoorHitChanceMultiplier = 0.45
end

if HTT.Config.HostileAttackIndoorDamageMultiplier == nil then
    HTT.Config.HostileAttackIndoorDamageMultiplier = 0.35
end

if HTT.Config.HostileAttackIndoorInjuryChanceMultiplier == nil then
    HTT.Config.HostileAttackIndoorInjuryChanceMultiplier = 0.50
end

if HTT.Config.HostileAttackIndoorProtection == nil then
    HTT.Config.HostileAttackIndoorProtection = true
end

if HTT.Config.EnableDirectionalSoundIndicator == nil then
    HTT.Config.EnableDirectionalSoundIndicator = true
end

if HTT.Config.BombardmentFirstStrikeDelayMinutes == nil then
    HTT.Config.BombardmentFirstStrikeDelayMinutes = 0.12
end

if HTT.Config.BombardmentRotorToPassSeconds == nil then
    HTT.Config.BombardmentRotorToPassSeconds = 12.0
end

if HTT.Config.BombardmentStrikeIntervalMinutes == nil then
    HTT.Config.BombardmentStrikeIntervalMinutes = 0.55
end

if HTT.Config.BombardmentRotorRepeatMinutes == nil then
    HTT.Config.BombardmentRotorRepeatMinutes = 0.28
end

if HTT.Config.BombardmentPassToExplosionSeconds == nil then
    HTT.Config.BombardmentPassToExplosionSeconds = 2.0
end

if HTT.Config.BombardmentPostExplosionEndSeconds == nil then
    HTT.Config.BombardmentPostExplosionEndSeconds = 5.0
end

if HTT.Config.BombardmentMinDistanceFromPlayer == nil then
    HTT.Config.BombardmentMinDistanceFromPlayer = 30
end

if HTT.Config.BombardmentMaxDistanceFromPlayer == nil then
    HTT.Config.BombardmentMaxDistanceFromPlayer = 78
end

if HTT.Config.BombardmentStrikeRadius == nil then
    HTT.Config.BombardmentStrikeRadius = 14
end

if HTT.Config.BombardmentInstantKillCount == nil then
    HTT.Config.BombardmentInstantKillCount = 14
end

if HTT.Config.BombardmentBurnTargetsPerStrike == nil then
    HTT.Config.BombardmentBurnTargetsPerStrike = 20
end

if HTT.Config.BombardmentBurnDamageMin == nil then
    HTT.Config.BombardmentBurnDamageMin = 0.25
end

if HTT.Config.BombardmentBurnDamageMax == nil then
    HTT.Config.BombardmentBurnDamageMax = 0.85
end

if HTT.Config.BombardmentSoundRadius == nil then
    HTT.Config.BombardmentSoundRadius = 120
end

if HTT.Config.BombardmentIndicatorDurationSeconds == nil then
    HTT.Config.BombardmentIndicatorDurationSeconds = 5.0
end

if HTT.Config.BombardmentIndicatorText == nil then
    HTT.Config.BombardmentIndicatorText = "BOOM"
end

if HTT.Config.DownedHeliApproachMinutes == nil then
    HTT.Config.DownedHeliApproachMinutes = 0.20
end

if HTT.Config.DownedHeliRotorToCollapseSeconds == nil then
    HTT.Config.DownedHeliRotorToCollapseSeconds = 12.0
end

if HTT.Config.DownedHeliCollapseToImpactSeconds == nil then
    HTT.Config.DownedHeliCollapseToImpactSeconds = 2.0
end

if HTT.Config.DownedHeliMinDistanceFromPlayer == nil then
    HTT.Config.DownedHeliMinDistanceFromPlayer = 45
end

if HTT.Config.DownedHeliMaxDistanceFromPlayer == nil then
    HTT.Config.DownedHeliMaxDistanceFromPlayer = 95
end

if HTT.Config.DownedHeliSoundRadius == nil then
    HTT.Config.DownedHeliSoundRadius = 170
end

if HTT.Config.DownedHeliAttractRadius == nil then
    HTT.Config.DownedHeliAttractRadius = 150
end

if HTT.Config.DownedHeliAttractVolume == nil then
    HTT.Config.DownedHeliAttractVolume = 150
end

if HTT.Config.DownedHeliAttractPulseCount == nil then
    HTT.Config.DownedHeliAttractPulseCount = 5
end

if HTT.Config.DownedHeliAttractPulseIntervalMinutes == nil then
    HTT.Config.DownedHeliAttractPulseIntervalMinutes = 0.20
end

if HTT.Config.ToxicTickSeconds == nil then
    HTT.Config.ToxicTickSeconds = 60
end

if HTT.Config.ToxicIndoorProtection == nil then
    HTT.Config.ToxicIndoorProtection = true
end

if HTT.Config.ToxicIndoorExposureMultiplier == nil then
    HTT.Config.ToxicIndoorExposureMultiplier = 0.40
end

if HTT.Config.ToxicDamagePerMinuteAtFullExposure == nil then
    HTT.Config.ToxicDamagePerMinuteAtFullExposure = 1.10
end

if HTT.Config.ToxicDamageMinPerMinute == nil then
    HTT.Config.ToxicDamageMinPerMinute = 0.12
end

if HTT.Config.ToxicDamageCurvePower == nil then
    HTT.Config.ToxicDamageCurvePower = 1.60
end

if HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure == nil then
    HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure = 0.01
end

if HTT.Config.ToxicExposureGainPerMin == nil then
    HTT.Config.ToxicExposureGainPerMin = 0.14
end

if HTT.Config.VanillaHookTriggerChance == nil then
    HTT.Config.VanillaHookTriggerChance = 100
end

if HTT.Config.EventWeightToxic == nil then
    HTT.Config.EventWeightToxic = 60
end

if HTT.Config.EventWeightSupportAttack == nil then
    HTT.Config.EventWeightSupportAttack = 30
end

if HTT.Config.EventWeightHostileAttack == nil then
    HTT.Config.EventWeightHostileAttack = 10
end

if HTT.Config.EnableEventToxic == nil then
    HTT.Config.EnableEventToxic = true
end

if HTT.Config.EnableEventSupportAttack == nil then
    HTT.Config.EnableEventSupportAttack = true
end

if HTT.Config.EnableEventHostileAttack == nil then
    HTT.Config.EnableEventHostileAttack = true
end

if HTT.Config.EnableEventAirBombardment == nil then
    HTT.Config.EnableEventAirBombardment = true
end

if HTT.Config.EnableEventDownedHeli == nil then
    HTT.Config.EnableEventDownedHeli = true
end

if HTT.Config.EnableEventSurveillanceEvent == nil then
    HTT.Config.EnableEventSurveillanceEvent = true
end

if HTT.Config.EnableEventIncendiarySweep == nil then
    HTT.Config.EnableEventIncendiarySweep = true
end

if HTT.Config.EnableIncendiarySweepPlayerRisk == nil then
    HTT.Config.EnableIncendiarySweepPlayerRisk = false
end

if HTT.Config.EnableEventSmokeCurtainEvent == nil then
    HTT.Config.EnableEventSmokeCurtainEvent = true
end

if HTT.Config.EnableEventEMIInterference == nil then
    HTT.Config.EnableEventEMIInterference = true
end

if HTT.Config.EnableEventSniperCover == nil then
    HTT.Config.EnableEventSniperCover = true
end

if HTT.Config.EnableEventPropagandaBroadcast == nil then
    HTT.Config.EnableEventPropagandaBroadcast = true
end

if HTT.Config.EnableEventFuelReclamation == nil then
    HTT.Config.EnableEventFuelReclamation = true
end

if HTT.Config.EnableEventMilitaryVehicleStrike == nil then
    HTT.Config.EnableEventMilitaryVehicleStrike = true
end

if HTT.Config.EnableEventUAVScan == nil then
    HTT.Config.EnableEventUAVScan = true
end

if HTT.Config.FuelReclamationDrainPercent == nil then
    HTT.Config.FuelReclamationDrainPercent = 10
end

if HTT.Config.MilitaryVehicleStrikeChance == nil then
    HTT.Config.MilitaryVehicleStrikeChance = 100
end

HTT.Events = HTT.Events or {
    toxic = {
        id = "toxic",
        durationHours = 1.5,
        approachSound = "HTT_loop_medium_rotor_distance",
        activeSound = "HTT_toxic_ambient",
        endSound = "HTT_toxic_release",
        loopSound = "HTT_toxic_ambient",
        radius = 18,
    },
    support_attack = {
        id = "support_attack",
        durationHours = 0.35,
        startSound = "HTT_loop_medium_rotor_distance",
        fireSound = "HTT_hostile_fire_far",
        hitSound = "HTT_hit_zombie",
        radius = 90,
    },
    hostile_attack = {
        id = "hostile_attack",
        durationHours = 0.35,
        startSound = "HTT_aggressive_combat",
        loopSound = "HTT_loop_low_rotor",
        voiceSound = "HTT_human_voice_transmission",
        fireSound = "HTT_hostile_fire_far",
        radius = 90,
    },
    air_bombardment = {
        id = "air_bombardment",
        durationHours = 1.00,
        startSound = "HTT_hight_altitude_rotor",
        passSound = "HTT_heli_pass_close",
        explosionSound = "HTT_explosion_far",
        fireSound = "HTT_heli_pass_close",
        hitSound = "HTT_explosion_far",
        radius = 120,
    },
    downed_heli = {
        id = "downed_heli",
        durationHours = 1.00,
        startSound = "HTT_hight_altitude_rotor",
        collapseSound = "HTT_heli_pass_close",
        impactSound = "HTT_explosion_impact",
        hitSound = "HTT_explosion_impact",
        radius = 120,
    },
    surveillance_event = {
        id = "surveillance_event",
        durationHours = 0.90,
        startSound = "HTT_loop_slowly_rotor",
        actionSound = "HTT_sensor_scan",
        radius = 36,
    },
    incendiary_sweep = {
        id = "incendiary_sweep",
        durationHours = 0.85,
        startSound = "HTT_loop_heavyfast_rotor",
        actionSound = "HTT_heavy_weapon",
        radius = 120,
    },
    smoke_curtain_event = {
        id = "smoke_curtain_event",
        durationHours = 0.90,
        startSound = "HTT_loop_hovering_rotor",
        actionSound = "HTT_hovering_low",
        radius = 54,
    },
    electromagnetic_interference_event = {
        id = "electromagnetic_interference_event",
        durationHours = 0.75,
        startSound = "HTT_loop_electromagnetic_interference",
        fireSound = "HTT_electromagnetic_pulse_01",
        hitSound = "HTT_electromagnetic_pulse_02",
        radius = 48,
    },
    sniper_cover_event = {
        id = "sniper_cover_event",
        durationHours = 0.70,
        startSound = "HTT_loop_tactical_rotor",
        fireSound = "HTT_precision_rifle",
        hitSound = "HTT_zombie_reaction_01",
        radius = 62,
    },
    propaganda_broadcast_event = {
        id = "propaganda_broadcast_event",
        durationHours = 0.95,
        startSound = "HTT_loop_medium_broadcasting_rotor",
        voiceSound = "HTT_distorted_public_announcement_01",
        fireSound = "HTT_distorted_public_announcement_02",
        radius = 72,
    },
    fuel_reclamation_event = {
        id = "fuel_reclamation_event",
        durationHours = 0.60,
        startSound = "HTT_stable_hover_rotor",
        actionSound = "HTT_fuel_extraction",
        radius = 76,
    },
    military_vehicle_strike_event = {
        id = "military_vehicle_strike_event",
        durationHours = 0.55,
        startSound = "HTT_military_rotor",
        actionSound = "HTT_aerial_strike",
        radius = 72,
    },
    uav_scan_event = {
        id = "uav_scan_event",
        durationHours = 0.80,
        startSound = "HTT_uav_reconnaissance_rotor",
        actionSound = "HTT_tactical_scan",
        radius = 36,
    },
}

HTT.EventToggleConfigKey = HTT.EventToggleConfigKey or {
    toxic = "EnableEventToxic",
    support_attack = "EnableEventSupportAttack",
    hostile_attack = "EnableEventHostileAttack",
    air_bombardment = "EnableEventAirBombardment",
    downed_heli = "EnableEventDownedHeli",
    surveillance_event = "EnableEventSurveillanceEvent",
    incendiary_sweep = "EnableEventIncendiarySweep",
    smoke_curtain_event = "EnableEventSmokeCurtainEvent",
    electromagnetic_interference_event = "EnableEventEMIInterference",
    sniper_cover_event = "EnableEventSniperCover",
    propaganda_broadcast_event = "EnableEventPropagandaBroadcast",
    fuel_reclamation_event = "EnableEventFuelReclamation",
    military_vehicle_strike_event = "EnableEventMilitaryVehicleStrike",
    uav_scan_event = "EnableEventUAVScan",
}

function HTT.log(msg)
    print("[HTT] " .. tostring(msg))
end

function HTT.isModEnabled()
    local value = HTT.Config and HTT.Config.EnableMod
    if value == nil then
        return true
    end
    if type(value) == "boolean" then
        return value
    end

    local s = string.lower(tostring(value))
    return s ~= "false" and s ~= "0" and s ~= "off" and s ~= "no"
end

function HTT.isEventEnabled(eventId)
    if HTT.isModEnabled and not HTT.isModEnabled() then
        return false
    end

    local id = tostring(eventId or "")
    if id == "" then
        return false
    end

    local toggleKey = HTT.EventToggleConfigKey and HTT.EventToggleConfigKey[id] or nil
    if not toggleKey then
        return true
    end

    local value = HTT.Config and HTT.Config[toggleKey]
    if value == nil then
        return true
    end
    if type(value) == "boolean" then
        return value
    end

    local s = string.lower(tostring(value))
    return s ~= "false" and s ~= "0" and s ~= "off" and s ~= "no"
end

function HTT.getEventDefinition(eventId)
    if not eventId then
        return nil
    end

    return HTT.Events[tostring(eventId)]
end

function HTT.toNumber(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return parsed
end

function HTT.secondsToWorldHours(seconds, fallbackSeconds)
    local sec = HTT.toNumber(seconds, fallbackSeconds)
    if sec == nil or sec <= 0 then
        return 0
    end

    local gameTime = getGameTime and getGameTime() or nil
    local minutesPerDay = nil
    if gameTime and gameTime.getMinutesPerDay then
        minutesPerDay = HTT.toNumber(gameTime:getMinutesPerDay(), nil)
    end

    if minutesPerDay and minutesPerDay > 0 then
        return sec * (24 / (minutesPerDay * 60))
    end

    return sec / 3600
end

local function isPlayerSleeping(player)
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
            return true
        end
    end

    if player.isSleeping then
        local ok, sleeping = pcall(function()
            return player:isSleeping()
        end)
        if ok and sleeping then
            return true
        end
    end

    return false
end

function HTT.isAnyPlayerSleeping()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players.size and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if isPlayerSleeping(p) then
                return true
            end
        end
        return false
    end

    if getNumActivePlayers and getSpecificPlayer then
        local count = HTT.toNumber(getNumActivePlayers(), 0)
        for i = 0, count - 1 do
            local p = getSpecificPlayer(i)
            if isPlayerSleeping(p) then
                return true
            end
        end
    end

    local p = getPlayer and getPlayer() or nil
    return isPlayerSleeping(p)
end

function HTT.isTimeFastForward()
    local inServer = isServer and isServer() or false
    local inClient = isClient and isClient() or false
    local isDedicatedServer = inServer and not inClient

    local anySleeping = HTT.isAnyPlayerSleeping and HTT.isAnyPlayerSleeping() or false
    if anySleeping then
        return true
    end

    -- On dedicated server getGameSpeed() may be > 1 even when nobody sleeps.
    -- Use actual sleeping players as the only guard there.
    if isDedicatedServer then
        return false
    end

    if getGameSpeed then
        local ok, speed = pcall(function()
            return getGameSpeed()
        end)
        if ok then
            local s = HTT.toNumber(speed, 1)
            if s and s > 1 then
                return true
            end
        end
    end

    return false
end

function HTT.shouldBlockEventsForSleep()
    if HTT.Config and HTT.Config.DisableEventsDuringSleep == false then
        return false
    end

    return HTT.isTimeFastForward and HTT.isTimeFastForward() or false
end

local function clampNumber(value, minValue, maxValue, fallback)
    local n = HTT.toNumber(value, fallback)
    if n == nil then
        return fallback
    end
    if minValue ~= nil and n < minValue then
        n = minValue
    end
    if maxValue ~= nil and n > maxValue then
        n = maxValue
    end
    return n
end

function HTT.normalizeEventCooldownHours(value, fallback, preserveLegacyZero)
    local n = HTT.toNumber(value, fallback)
    if n == nil then
        return fallback
    end

    if preserveLegacyZero == true and n <= 0 then
        return 72.0
    end

    if n < 6.0 then
        n = 6.0
    end
    if n > 168.0 then
        n = 168.0
    end
    return n
end

function HTT.getConfiguredEventDurationHours(eventId, fallback)
    local fallbackDuration = clampNumber(fallback, 0.05, 24.0, 1.5)
    local defaultDuration = clampNumber(
        HTT.Config and HTT.Config.DefaultEventDurationHours,
        0.05,
        24.0,
        fallbackDuration
    )

    if tostring(eventId or "") == "toxic" then
        return clampNumber(
            HTT.Config and HTT.Config.ToxicEventDurationHours,
            0.05,
            24.0,
            defaultDuration
        )
    end

    return defaultDuration
end

local function parseSandboxBool(value, fallback)
    if value == nil then
        return fallback
    end
    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end

    local s = string.lower(tostring(value))
    if s == "true" or s == "1" or s == "yes" or s == "on" then
        return true
    end
    if s == "false" or s == "0" or s == "no" or s == "off" then
        return false
    end

    return fallback
end

local function normalizePresetName(presetId)
    local value = string.lower(tostring(presetId or "normal"))
    if value == "1" then
        return "casual"
    end
    if value == "2" then
        return "normal"
    end
    if value == "3" then
        return "hardcore"
    end
    if value == "easy" then
        return "casual"
    end
    if value == "hard" then
        return "hardcore"
    end
    if value == "casual" then
        return "casual"
    end
    if value == "hardcore" then
        return "hardcore"
    end
    return "normal"
end

local function normalizeToxicDamagePresetName(presetId)
    local value = string.lower(tostring(presetId or "soft"))
    if value == "1" then
        return "soft"
    end
    if value == "2" then
        return "medium"
    end
    if value == "3" then
        return "hardcore"
    end
    if value == "easy" or value == "casual" then
        return "soft"
    end
    if value == "normal" then
        return "medium"
    end
    if value == "hard" then
        return "hardcore"
    end
    if value == "medium" then
        return "medium"
    end
    if value == "hardcore" then
        return "hardcore"
    end
    return "soft"
end

local function normalizeFuelDrainPercent(value)
    local raw = tostring(value or "2")
    local asNumber = tonumber(raw)
    if asNumber ~= nil then
        if asNumber == 1 then
            return 5
        end
        if asNumber == 2 then
            return 10
        end
        if asNumber == 3 then
            return 25
        end
        if asNumber <= 1 then
            asNumber = asNumber * 100
        end
        if asNumber < 7.5 then
            return 5
        end
        if asNumber < 17.5 then
            return 10
        end
        return 25
    end

    local key = string.lower(raw)
    if key == "low" or key == "small" or key == "5" then
        return 5
    end
    if key == "high" or key == "large" or key == "25" then
        return 25
    end
    return 10
end

function HTT.applyBalancePreset(presetId)
    local preset = normalizePresetName(presetId)
    HTT.Config.BalancePreset = preset

    if preset == "casual" then
        HTT.Config.HostileAttackBurstMinutes = 0.90
        HTT.Config.HostileAttackHitChance = 22
        HTT.Config.HostileAttackHitCooldownMinutes = 2.0
        HTT.Config.HostileAttackMaxHitsPerEvent = 5
        HTT.Config.HostileAttackDamageMin = 0.08
        HTT.Config.HostileAttackDamageMax = 0.28
        HTT.Config.HostileAttackFractureChance = 0.08
        HTT.Config.SupportAttackBurstMinutes = 0.28
        HTT.Config.ToxicNearZombieCount = 10
        HTT.Config.ToxicAmbientRepeatMinutes = 2.6
    elseif preset == "hardcore" then
        HTT.Config.HostileAttackBurstMinutes = 0.38
        HTT.Config.HostileAttackHitChance = 50
        HTT.Config.HostileAttackHitCooldownMinutes = 0.70
        HTT.Config.HostileAttackMaxHitsPerEvent = 12
        HTT.Config.HostileAttackDamageMin = 0.18
        HTT.Config.HostileAttackDamageMax = 0.62
        HTT.Config.HostileAttackFractureChance = 0.24
        HTT.Config.SupportAttackBurstMinutes = 0.15
        HTT.Config.ToxicNearZombieCount = 6
        HTT.Config.ToxicAmbientRepeatMinutes = 1.2
    else
        HTT.Config.HostileAttackBurstMinutes = 0.55
        HTT.Config.HostileAttackHitChance = 32
        HTT.Config.HostileAttackHitCooldownMinutes = 1.25
        HTT.Config.HostileAttackMaxHitsPerEvent = 8
        HTT.Config.HostileAttackDamageMin = 0.12
        HTT.Config.HostileAttackDamageMax = 0.45
        HTT.Config.HostileAttackFractureChance = 0.16
        HTT.Config.SupportAttackBurstMinutes = 0.20
        HTT.Config.ToxicNearZombieCount = 8
        HTT.Config.ToxicAmbientRepeatMinutes = 2.0
    end

    return preset
end

HTT.applyBalancePreset(HTT.Config.BalancePreset)

function HTT.applyToxicDamagePreset(presetId, preserveTick)
    local preset = normalizeToxicDamagePresetName(presetId)
    HTT.Config.ToxicDamagePreset = preset
    local keepTick = preserveTick == true

    local function applyPresetTick(seconds)
        if not keepTick then
            HTT.Config.ToxicTickSeconds = seconds
        end
    end

    if preset == "medium" then
        -- Medium profile based on requested in-game values.
        applyPresetTick(15)
        HTT.Config.ToxicEventDurationHours = 0.75
        HTT.Config.ToxicDamagePerMinuteAtFullExposure = 5.00
        HTT.Config.ToxicDamageMinPerMinute = 0.40
        HTT.Config.ToxicDamageCurvePower = 1.00
        HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure = 0.16
        HTT.Config.ToxicExposureGainPerMin = 0.40
    elseif preset == "hardcore" then
        -- Hardcore profile: lethal over sustained exposure, with shorter ticks so damage feels progressive.
        applyPresetTick(8)
        HTT.Config.ToxicEventDurationHours = 1.50
        HTT.Config.ToxicDamagePerMinuteAtFullExposure = 8.00
        HTT.Config.ToxicDamageMinPerMinute = 0.75
        HTT.Config.ToxicDamageCurvePower = 0.85
        HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure = 0.30
        HTT.Config.ToxicExposureGainPerMin = 0.55
    else
        -- Soft profile (base/default values).
        applyPresetTick(30)
        HTT.Config.ToxicEventDurationHours = 0.25
        HTT.Config.ToxicDamagePerMinuteAtFullExposure = 1.10
        HTT.Config.ToxicDamageMinPerMinute = 0.12
        HTT.Config.ToxicDamageCurvePower = 1.60
        HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure = 0.01
        HTT.Config.ToxicExposureGainPerMin = 0.14
    end

    return preset
end

HTT.applyToxicDamagePreset(HTT.Config.ToxicDamagePreset)

local HTT_ROTOR_SOUND_IDS = {
    HTT_heli_loop_far = true,
    HTT_hight_altitude_rotor = true,
    HTT_hovering_low = true,
    HTT_loop_hovering_rotor = true,
    HTT_loop_heavyfast_rotor = true,
    HTT_loop_low_rotor = true,
    HTT_loop_medium_broadcasting_rotor = true,
    HTT_loop_medium_rotor = true,
    HTT_loop_medium_rotor_distance = true,
    HTT_loop_slowly_rotor = true,
    HTT_loop_tactical_rotor = true,
    HTT_military_rotor = true,
    HTT_stable_hover_rotor = true,
    HTT_uav_reconnaissance_rotor = true,
}

function HTT.isRotorSoundId(soundName)
    return HTT_ROTOR_SOUND_IDS[tostring(soundName or "")] == true
end

function HTT.getResolvedRotorSoundId(soundName)
    local raw = tostring(soundName or "")
    if raw == "" then
        return raw
    end

    if HTT.Config.UseVanillaRotorSoundsInEvents == true and HTT.isRotorSoundId(raw) then
        return tostring(HTT.Config.VanillaRotorSoundId or "Helicopter")
    end

    return raw
end

function HTT.pickWeightedVanillaEventId()
    local weighted = {
        { id = "toxic", w = math.max(0, HTT.toNumber(HTT.Config.EventWeightToxic, 60) or 0) },
        { id = "support_attack", w = math.max(0, HTT.toNumber(HTT.Config.EventWeightSupportAttack, 30) or 0) },
        { id = "hostile_attack", w = math.max(0, HTT.toNumber(HTT.Config.EventWeightHostileAttack, 10) or 0) },
        { id = "surveillance_event", w = 16 },
        { id = "incendiary_sweep", w = 10 },
        { id = "smoke_curtain_event", w = 14 },
        { id = "electromagnetic_interference_event", w = 12 },
        { id = "sniper_cover_event", w = 14 },
        { id = "propaganda_broadcast_event", w = 15 },
        { id = "fuel_reclamation_event", w = 10 },
        { id = "military_vehicle_strike_event", w = 10 },
        { id = "uav_scan_event", w = 12 },
    }

    local total = 0
    for i = 1, #weighted do
        if HTT.isEventEnabled(weighted[i].id) then
            total = total + weighted[i].w
        end
    end

    if total <= 0 then
        local defaultId = tostring(HTT.Config.DefaultEventId or "")
        if defaultId ~= "" and HTT.isEventEnabled(defaultId) and HTT.getEventDefinition(defaultId) then
            return defaultId
        end

        for i = 1, #weighted do
            if HTT.isEventEnabled(weighted[i].id) and HTT.getEventDefinition(weighted[i].id) then
                return weighted[i].id
            end
        end

        return HTT.Config.DefaultEventId
    end

    local roll = ZombRandFloat(0, total)
    local acc = 0
    for i = 1, #weighted do
        if HTT.isEventEnabled(weighted[i].id) then
            acc = acc + weighted[i].w
            if roll <= acc then
                return weighted[i].id
            end
        end
    end

    for i = #weighted, 1, -1 do
        if HTT.isEventEnabled(weighted[i].id) then
            return weighted[i].id
        end
    end
    return HTT.Config.DefaultEventId
end

local function buildSandboxSignature(svRoot)
    if not svRoot then
        return nil
    end

    return table.concat({
        tostring(svRoot.BalancePreset),
        tostring(svRoot.EnableMod),
        tostring(svRoot.DefaultEventDurationHours),
        tostring(svRoot.ToxicEventDurationHours),
        tostring(svRoot.EventCooldownHours),
        tostring(svRoot.EnableRandomEventCooldown),
        tostring(svRoot.EnableFixedDailyEventHour),
        tostring(svRoot.FixedDailyEventHour),
        tostring(svRoot.DisableEventsDuringSleep),
        tostring(svRoot.EnableVanillaHelicopterHook),
        tostring(svRoot.UseVanillaRotorSoundsInEvents),
        tostring(svRoot.ToxicDamagePreset),
        tostring(svRoot.ToxicTickSeconds),
        tostring(svRoot.ToxicDamagePerMinuteAtFullExposure),
        tostring(svRoot.ToxicDamageMinPerMinute),
        tostring(svRoot.ToxicDamageCurvePower),
        tostring(svRoot.ToxicExtraDamagePerMinuteOnMaxExposure),
        tostring(svRoot.ToxicExposureGainPerMin),
        tostring(svRoot.HostileAttackHitChance),
        tostring(svRoot.VanillaHookTriggerChance),
        tostring(svRoot.EventWeightToxic),
        tostring(svRoot.EventWeightSupportAttack),
        tostring(svRoot.EventWeightHostileAttack),
        tostring(svRoot.EnableEventToxic),
        tostring(svRoot.EnableEventSupportAttack),
        tostring(svRoot.EnableEventHostileAttack),
        tostring(svRoot.EnableEventAirBombardment),
        tostring(svRoot.EnableEventDownedHeli),
        tostring(svRoot.EnableEventSurveillanceEvent),
        tostring(svRoot.EnableEventIncendiarySweep),
        tostring(svRoot.EnableIncendiarySweepPlayerRisk),
        tostring(svRoot.IncendiarySweepPlayerRiskChance),
        tostring(svRoot.EnableEventSmokeCurtainEvent),
        tostring(svRoot.EnableEventEMIInterference),
        tostring(svRoot.EnableEventSniperCover),
        tostring(svRoot.EnableEventPropagandaBroadcast),
        tostring(svRoot.EnableEventFuelReclamation),
        tostring(svRoot.EnableEventMilitaryVehicleStrike),
        tostring(svRoot.EnableEventUAVScan),
        tostring(svRoot.FuelReclamationDrainPercent),
        tostring(svRoot.MilitaryVehicleStrikeChance),
    }, "|")
end

function HTT.applySandboxOptions()
    local svRoot = SandboxVars and SandboxVars.HTT or nil
    if not svRoot then
        return false
    end
    local signature = buildSandboxSignature(svRoot)
    local signatureChanged = signature ~= HTT._lastSandboxSignature
    HTT._lastSandboxSignature = signature

    local preset = normalizePresetName(svRoot.BalancePreset)
    HTT.applyBalancePreset(preset)
    HTT.Config.EnableMod = parseSandboxBool(svRoot.EnableMod, HTT.Config.EnableMod)
    local randomCooldownEnabled = parseSandboxBool(
        svRoot.EnableRandomEventCooldown,
        HTT.Config.EnableRandomEventCooldown
    )

    HTT.Config.DefaultEventDurationHours = clampNumber(
        svRoot.DefaultEventDurationHours,
        0.05,
        24.0,
        HTT.Config.DefaultEventDurationHours
    )
    HTT.Config.ToxicEventDurationHours = clampNumber(
        svRoot.ToxicEventDurationHours,
        0.05,
        24.0,
        HTT.Config.DefaultEventDurationHours
    )
    HTT.Config.EventCooldownHours = HTT.normalizeEventCooldownHours(
        svRoot.EventCooldownHours,
        HTT.Config.EventCooldownHours,
        true
    )
    HTT.Config.EnableRandomEventCooldown = randomCooldownEnabled
    HTT.Config.EnableFixedDailyEventHour = parseSandboxBool(
        svRoot.EnableFixedDailyEventHour,
        HTT.Config.EnableFixedDailyEventHour
    )
    HTT.Config.FixedDailyEventHour = clampNumber(
        svRoot.FixedDailyEventHour,
        0.0,
        23.75,
        HTT.Config.FixedDailyEventHour
    )
    HTT.Config.DisableEventsDuringSleep = parseSandboxBool(
        svRoot.DisableEventsDuringSleep,
        HTT.Config.DisableEventsDuringSleep
    )
    HTT.Config.EnableVanillaHelicopterHook = parseSandboxBool(
        svRoot.EnableVanillaHelicopterHook,
        HTT.Config.EnableVanillaHelicopterHook
    )
    HTT.Config.UseVanillaRotorSoundsInEvents = parseSandboxBool(
        svRoot.UseVanillaRotorSoundsInEvents,
        HTT.Config.UseVanillaRotorSoundsInEvents
    )
    if HTT.Server then
        HTT.Server._autoNextAllowedHour = nil
        HTT.Server._autoLastCooldownHours = nil
        HTT.Server._autoSchedulerStateLoaded = false
        if HTT.Server.persistAutoSchedulerState then
            HTT.Server.persistAutoSchedulerState()
        end
    end

    local sandboxToxicTickSeconds = clampNumber(svRoot.ToxicTickSeconds, 5, 300, HTT.Config.ToxicTickSeconds)
    HTT.Config.ToxicTickSeconds = sandboxToxicTickSeconds
    if svRoot.ToxicDamagePreset ~= nil then
        local preserveTick = false
        if sandboxToxicTickSeconds ~= nil then
            preserveTick = math.abs(sandboxToxicTickSeconds - 60.0) > 0.001
        end
        HTT.applyToxicDamagePreset(svRoot.ToxicDamagePreset, preserveTick)
    else
        -- Legacy fallback for old worlds before toxic presets existed.
        HTT.Config.ToxicDamagePreset = "legacy"
        HTT.Config.ToxicDamagePerMinuteAtFullExposure = clampNumber(
            svRoot.ToxicDamagePerMinuteAtFullExposure,
            0.0,
            10.0,
            HTT.Config.ToxicDamagePerMinuteAtFullExposure
        )
        HTT.Config.ToxicDamageMinPerMinute = clampNumber(
            svRoot.ToxicDamageMinPerMinute,
            0.0,
            5.0,
            HTT.Config.ToxicDamageMinPerMinute
        )
        HTT.Config.ToxicDamageCurvePower = clampNumber(
            svRoot.ToxicDamageCurvePower,
            0.2,
            5.0,
            HTT.Config.ToxicDamageCurvePower
        )
        HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure = clampNumber(
            svRoot.ToxicExtraDamagePerMinuteOnMaxExposure,
            0.0,
            2.0,
            HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure
        )
        HTT.Config.ToxicExposureGainPerMin = clampNumber(
            svRoot.ToxicExposureGainPerMin,
            0.0,
            1.0,
            HTT.Config.ToxicExposureGainPerMin
        )
    end

    local hostileHitChanceRaw = HTT.normalizePercentValue(
        svRoot.HostileAttackHitChance,
        HTT.normalizePercentValue(HTT.Config.HostileAttackHitChance, 32, 1),
        1
    )
    HTT.Config.HostileAttackHitChance = hostileHitChanceRaw

    HTT.Config.VanillaHookTriggerChance = clampNumber(
        svRoot.VanillaHookTriggerChance,
        0,
        100,
        HTT.Config.VanillaHookTriggerChance
    )
    HTT.Config.EventWeightToxic = clampNumber(svRoot.EventWeightToxic, 0, 1000, HTT.Config.EventWeightToxic)
    HTT.Config.EventWeightSupportAttack = clampNumber(
        svRoot.EventWeightSupportAttack,
        0,
        1000,
        HTT.Config.EventWeightSupportAttack
    )
    HTT.Config.EventWeightHostileAttack = clampNumber(
        svRoot.EventWeightHostileAttack,
        0,
        1000,
        HTT.Config.EventWeightHostileAttack
    )
    HTT.Config.EnableEventToxic = parseSandboxBool(svRoot.EnableEventToxic, HTT.Config.EnableEventToxic)
    HTT.Config.EnableEventSupportAttack = parseSandboxBool(
        svRoot.EnableEventSupportAttack,
        HTT.Config.EnableEventSupportAttack
    )
    HTT.Config.EnableEventHostileAttack = parseSandboxBool(
        svRoot.EnableEventHostileAttack,
        HTT.Config.EnableEventHostileAttack
    )
    HTT.Config.EnableEventAirBombardment = parseSandboxBool(
        svRoot.EnableEventAirBombardment,
        HTT.Config.EnableEventAirBombardment
    )
    HTT.Config.EnableEventDownedHeli = parseSandboxBool(
        svRoot.EnableEventDownedHeli,
        HTT.Config.EnableEventDownedHeli
    )
    HTT.Config.EnableEventSurveillanceEvent = parseSandboxBool(
        svRoot.EnableEventSurveillanceEvent,
        HTT.Config.EnableEventSurveillanceEvent
    )
    HTT.Config.EnableEventIncendiarySweep = parseSandboxBool(
        svRoot.EnableEventIncendiarySweep,
        HTT.Config.EnableEventIncendiarySweep
    )
    if svRoot.EnableIncendiarySweepPlayerRisk ~= nil then
        HTT.Config.EnableIncendiarySweepPlayerRisk = parseSandboxBool(
            svRoot.EnableIncendiarySweepPlayerRisk,
            HTT.Config.EnableIncendiarySweepPlayerRisk
        )
    else
        -- Legacy compatibility: old builds used a percent chance option.
        local legacyRiskChance = clampNumber(svRoot.IncendiarySweepPlayerRiskChance, 0, 100, nil)
        if legacyRiskChance ~= nil then
            HTT.Config.EnableIncendiarySweepPlayerRisk = legacyRiskChance > 0
        end
    end
    HTT.Config.EnableEventSmokeCurtainEvent = parseSandboxBool(
        svRoot.EnableEventSmokeCurtainEvent,
        HTT.Config.EnableEventSmokeCurtainEvent
    )
    HTT.Config.EnableEventEMIInterference = parseSandboxBool(
        svRoot.EnableEventEMIInterference,
        HTT.Config.EnableEventEMIInterference
    )
    HTT.Config.EnableEventSniperCover = parseSandboxBool(
        svRoot.EnableEventSniperCover,
        HTT.Config.EnableEventSniperCover
    )
    HTT.Config.EnableEventPropagandaBroadcast = parseSandboxBool(
        svRoot.EnableEventPropagandaBroadcast,
        HTT.Config.EnableEventPropagandaBroadcast
    )
    HTT.Config.EnableEventFuelReclamation = parseSandboxBool(
        svRoot.EnableEventFuelReclamation,
        HTT.Config.EnableEventFuelReclamation
    )
    HTT.Config.EnableEventMilitaryVehicleStrike = parseSandboxBool(
        svRoot.EnableEventMilitaryVehicleStrike,
        HTT.Config.EnableEventMilitaryVehicleStrike
    )
    HTT.Config.EnableEventUAVScan = parseSandboxBool(
        svRoot.EnableEventUAVScan,
        HTT.Config.EnableEventUAVScan
    )
    HTT.Config.FuelReclamationDrainPercent = normalizeFuelDrainPercent(
        svRoot.FuelReclamationDrainPercent
    )
    HTT.Config.MilitaryVehicleStrikeChance = clampNumber(
        svRoot.MilitaryVehicleStrikeChance,
        0,
        100,
        HTT.Config.MilitaryVehicleStrikeChance
    )

    if HTT.isModEnabled and not HTT.isModEnabled() then
        local state = HTT.Server and HTT.Server.state or nil
        if state and state.active and HTT.Server.stopEvent then
            HTT.Server.stopEvent("mod-disabled")
        end
    end

    if signatureChanged then
        HTT.log(string.format(
        "Sandbox applied preset=%s toxicPreset=%s modEnabled=%s eventDuration=%.2fh toxicEventDuration=%.2fh eventCooldown=%.2fh randomCooldown=%s fixedDailyHour=%s dailyHour=%.2f disableDuringSleep=%s toxicTick=%.1fs toxicDmgPerMin=%.3f toxicMinPerMin=%.3f toxicCurve=%.2f toxicExtraPerMin=%.3f toxicExpGain=%.3f hostileHit=%.1f%% vanillaChance=%.1f weights(t/s/h)=(%.0f/%.0f/%.0f) enabled(t/s/h/b/c/v/i/m)=(%s/%s/%s/%s/%s/%s/%s/%s) incendiaryRisk=%s",
            tostring(HTT.Config.BalancePreset),
            tostring(HTT.Config.ToxicDamagePreset),
            tostring(HTT.isModEnabled and HTT.isModEnabled()),
            HTT.toNumber(HTT.Config.DefaultEventDurationHours, 1.5),
            HTT.toNumber(HTT.Config.ToxicEventDurationHours, HTT.toNumber(HTT.Config.DefaultEventDurationHours, 1.5)),
        HTT.toNumber(HTT.Config.EventCooldownHours, 72.0),
            tostring(HTT.Config.EnableRandomEventCooldown),
            tostring(HTT.Config.EnableFixedDailyEventHour),
            HTT.toNumber(HTT.Config.FixedDailyEventHour, 9.0),
            tostring(HTT.Config.DisableEventsDuringSleep),
            HTT.toNumber(HTT.Config.ToxicTickSeconds, 60),
            HTT.toNumber(HTT.Config.ToxicDamagePerMinuteAtFullExposure, 1.10),
            HTT.toNumber(HTT.Config.ToxicDamageMinPerMinute, 0.12),
            HTT.toNumber(HTT.Config.ToxicDamageCurvePower, 1.60),
            HTT.toNumber(HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure, 0.01),
            HTT.toNumber(HTT.Config.ToxicExposureGainPerMin, 0.14),
            HTT.normalizePercentValue(HTT.Config.HostileAttackHitChance, 32, 1),
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
    end

    return true
end

function HTT.refreshSandboxOptionsIfChanged()
    local svRoot = SandboxVars and SandboxVars.HTT or nil
    if not svRoot then
        return false
    end

    local signature = buildSandboxSignature(svRoot)
    if signature == HTT._lastSandboxSignature then
        return false
    end

    return HTT.applySandboxOptions()
end

if HTT._coreSandboxHooked ~= true then
    HTT._coreSandboxHooked = true
    if Events and Events.OnInitWorld and Events.OnInitWorld.Add then
        Events.OnInitWorld.Add(HTT.applySandboxOptions)
    end
    if Events and Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(HTT.applySandboxOptions)
    end
    if Events and Events.OnSandboxOptionsChanged and Events.OnSandboxOptionsChanged.Add then
        Events.OnSandboxOptionsChanged.Add(HTT.applySandboxOptions)
    end
    if Events and Events.EveryOneMinute and Events.EveryOneMinute.Add then
        Events.EveryOneMinute.Add(HTT.refreshSandboxOptionsIfChanged)
    end
end
