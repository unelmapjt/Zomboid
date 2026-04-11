require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerToxic = HTT.ServerToxic or {}

if HTT._serverToxicLoaded then
    return
end
HTT._serverToxicLoaded = true

local RESISTANCE_MIN = 0.6
local RESISTANCE_MAX = 1.4
local EXPOSURE_GAIN_PER_MIN = 0.14
local EXPOSURE_DECAY_PER_MIN = 0.08
local EXPOSURE_MAX = 1.0
local PANIC_GAIN = 3
local STRESS_GAIN = 0.04
local SICKNESS_GAIN = 3.0
local PANIC_DECAY_PER_MIN = 6.0
local STRESS_DECAY_PER_MIN = 0.035
local SICKNESS_DECAY_PER_MIN = 1.4
local PLAYER_DAMAGE_EXPOSURE_THRESHOLD = 0.10
local PLAYER_SICKNESS_EXPOSURE_THRESHOLD = 0.18
local BALANCE_SICKNESS_SCALE = {
    casual = 0.55,
    normal = 0.70,
    hardcore = 1.00,
}
local TOXIC_SICKNESS_SCALE = {
    soft = 0.60,
    medium = 0.78,
    hardcore = 1.00,
    legacy = 0.78,
}
-- Damage tuning (per-minute model)
local TOXIC_DAMAGE_PER_MIN_AT_FULL = 1.10
local TOXIC_DAMAGE_MIN_PER_MIN = 0.12
local TOXIC_DAMAGE_CURVE_POWER = 1.6
local TOXIC_EXTRA_MAX_PER_MIN = 0.01
local LINGERING_RECOVERY_DECAY_MULTIPLIER = 1.10
local ATTRACT_RADIUS = 120
local ATTRACT_VOLUME = 120
local TOXIC_ACTIVE_SOUND_VOLUME_MUL = 0.52
local TOXIC_ACTIVE_SOUND_MIN_REPEAT_SECONDS = 31.0
local nextToxicTickHour = 0

local function normalizeBalancePresetName(presetId)
    local value = string.lower(tostring(presetId or "normal"))
    if value == "1" or value == "easy" or value == "casual" then
        return "casual"
    end
    if value == "3" or value == "hard" or value == "hardcore" then
        return "hardcore"
    end
    return "normal"
end

local function normalizeToxicDamagePresetName(presetId)
    local value = string.lower(tostring(presetId or "soft"))
    if value == "1" or value == "easy" or value == "casual" or value == "soft" then
        return "soft"
    end
    if value == "3" or value == "hard" or value == "hardcore" then
        return "hardcore"
    end
    if value == "legacy" then
        return "legacy"
    end
    return "medium"
end

local function isHardcoreToxicPreset()
    local toxicPreset = normalizeToxicDamagePresetName(HTT and HTT.Config and HTT.Config.ToxicDamagePreset or "soft")
    if toxicPreset == "hardcore" then
        return true
    end

    local balancePreset = normalizeBalancePresetName(HTT and HTT.Config and HTT.Config.BalancePreset or "normal")
    return balancePreset == "hardcore"
end

local function getSicknessGainScale()
    local balancePreset = normalizeBalancePresetName(HTT and HTT.Config and HTT.Config.BalancePreset or "normal")
    local toxicPreset = normalizeToxicDamagePresetName(HTT and HTT.Config and HTT.Config.ToxicDamagePreset or "soft")
    local balanceScale = BALANCE_SICKNESS_SCALE[balancePreset] or 1.0
    local toxicScale = TOXIC_SICKNESS_SCALE[toxicPreset] or 1.0
    if balanceScale < toxicScale then
        return balanceScale
    end
    return toxicScale
end

local function getSicknessExposureThreshold()
    if isHardcoreToxicPreset() then
        return PLAYER_DAMAGE_EXPOSURE_THRESHOLD
    end
    return PLAYER_SICKNESS_EXPOSURE_THRESHOLD
end

local MASK_MULTIPLIER_BY_FULLTYPE = {
    ["Base.Hat_NBCmask"] = 0.0,
    ["Base.Hat_GasMask"] = 0.0,
    ["Base.Hat_GasMask_nofilter"] = 0.0,
    ["Base.Hat_ImprovisedGasMask"] = 0.0,
    ["Base.Hat_BuildersRespirator"] = 0.0,
    ["Base.Hat_DustMask"] = 0.0,
    ["Base.Hat_SurgicalMask"] = 0.0,
    ["Base.Hat_BandanaMask"] = 0.0,
    ["Base.Hat_Bandana_Green"] = 0.0,
    ["Base.Hat_Bandana"] = 0.0,
    ["Base.Hat_RagBandanaMask"] = 0.0,
    ["Base.ShemaghScarf_Green"] = 0.0,
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

local function inventoryHasAny(inv, fullTypes)
    if not inv then
        return false
    end

    for i = 1, #fullTypes do
        if inv:contains(fullTypes[i]) then
            return true
        end
    end

    return false
end

local function getItemConditionPenalty(item)
    if not item or not item.getConditionMax or not item.getCondition then
        return 1.0
    end

    local maxCondition = HTT.toNumber(item:getConditionMax(), 0)
    if maxCondition <= 0 then
        return 1.0
    end

    local condition = HTT.toNumber(item:getCondition(), maxCondition)
    local ratio = condition / maxCondition
    if ratio < 0 then
        ratio = 0
    elseif ratio > 1 then
        ratio = 1
    end

    -- Damaged filters/masks lose effectiveness.
    return 1.0 + ((1.0 - ratio) * 0.40)
end

local function getBestWornMaskMultiplier(player)
    if not player or not player.getWornItems then
        return nil
    end

    local wornItems = player:getWornItems()
    if not wornItems or not wornItems.size then
        return nil
    end

    local best = 1.0
    local foundKnown = false
    for i = 0, wornItems:size() - 1 do
        local worn = wornItems:get(i)
        local item = nil
        if worn and worn.getItem then
            item = worn:getItem()
        end

        local fullType = item and item.getFullType and item:getFullType() or nil
        local baseMultiplier = fullType and MASK_MULTIPLIER_BY_FULLTYPE[fullType] or nil
        if baseMultiplier then
            local effective = baseMultiplier * getItemConditionPenalty(item)
            if effective < 0 then
                effective = 0
            elseif effective > 1.0 then
                effective = 1.0
            end

            foundKnown = true
            if effective < best then
                best = effective
            end
        end
    end

    if foundKnown then
        return best
    end

    return 1.0
end

local function getMaskMultiplier(player)
    local fromWorn = getBestWornMaskMultiplier(player)
    if fromWorn ~= nil then
        return fromWorn
    end

    local inv = player and player:getInventory() or nil
    local fallbackByPriority = {
        "Base.Hat_NBCmask",
        "Base.Hat_GasMask",
        "Base.Hat_ImprovisedGasMask",
        "Base.Hat_BuildersRespirator",
        "Base.Hat_DustMask",
        "Base.Hat_SurgicalMask",
        "Base.Hat_BandanaMask",
        "Base.Hat_Bandana_Green",
        "Base.Hat_Bandana",
        "Base.ShemaghScarf_Green",
    }
    for i = 1, #fallbackByPriority do
        local fullType = fallbackByPriority[i]
        if inventoryHasAny(inv, { fullType }) then
            return MASK_MULTIPLIER_BY_FULLTYPE[fullType] or 1.0
        end
    end

    return 1.0
end

local function getUndergroundMultiplier(player)
    if not player then
        return 1.0
    end

    local z = player:getZ()
    if z >= 0 then
        return 1.0
    end

    local depth = math.abs(z)
    local reduction = math.min(depth * 0.25, 0.75)
    return 1.0 - reduction
end

local function isPlayerShelteredFromAir(player)
    if not player then
        return false
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

local function getPlayerToxicData(player)
    local md = player:getModData()
    md.HTT_Toxic = md.HTT_Toxic or {}

    local toxicData = md.HTT_Toxic
    toxicData.exposure = HTT.toNumber(toxicData.exposure, 0)
    toxicData.panic = HTT.toNumber(toxicData.panic, 0)
    toxicData.stress = HTT.toNumber(toxicData.stress, 0)
    toxicData.sickness = HTT.toNumber(toxicData.sickness, 0)

    return toxicData
end

local function setStat(stats, statName, value)
    if not stats then
        return
    end

    if statName == "PANIC" and stats.setPanic then
        stats:setPanic(value)
        return
    end
    if statName == "STRESS" and stats.setStress then
        stats:setStress(value)
        return
    end

    if statName == "FOOD_SICKNESS" or statName == "SICKNESS" then
        if stats.setSickness then
            local normalized = HTT.toNumber(value, 0)
            if normalized > 1 then
                normalized = normalized / 100.0
            end
            if normalized < 0 then
                normalized = 0
            elseif normalized > 1 then
                normalized = 1
            end
            stats:setSickness(normalized)
            return
        end
    end

    if CharacterStat and stats.set and CharacterStat[statName] then
        stats:set(CharacterStat[statName], value)
        return
    end

    if (statName == "FOOD_SICKNESS" or statName == "SICKNESS") and stats.setSickness then
        stats:setSickness(value)
    end
end

local function setBodyFoodSicknessLevel(bd, value)
    if not bd or not bd.setFoodSicknessLevel then
        return false
    end

    local level = HTT.toNumber(value, 0)
    if level < 0 then
        level = 0
    elseif level > 100 then
        level = 100
    end

    bd:setFoodSicknessLevel(level)
    return true
end

local function raiseBodyFoodSicknessFloor(bd, floorValue)
    if not bd or not bd.getFoodSicknessLevel then
        return false
    end

    local floorLevel = HTT.toNumber(floorValue, 0)
    if floorLevel <= 0 then
        return false
    end

    local current = HTT.toNumber(bd:getFoodSicknessLevel(), 0)
    if floorLevel > current then
        return setBodyFoodSicknessLevel(bd, floorLevel)
    end

    return false
end

local function syncToxicBodyDamage(bd)
    if not bd or not syncBodyPart or not BodyPartType or not bd.getBodyPart then
        return
    end

    local part = nil
    if BodyPartType.Torso_Upper then
        part = bd:getBodyPart(BodyPartType.Torso_Upper)
    end
    if not part and BodyPartType.Torso_Lower then
        part = bd:getBodyPart(BodyPartType.Torso_Lower)
    end
    if part then
        syncBodyPart(part, 0xFFFFFFFFFFF)
    end
end

local function applyFallbackBodyPartDamage(bd, damage)
    if not bd or not BodyPartType or not bd.getBodyPart then
        return false, nil
    end

    local part = nil
    if BodyPartType.Torso_Upper then
        part = bd:getBodyPart(BodyPartType.Torso_Upper)
    end
    if not part and BodyPartType.Torso_Lower then
        part = bd:getBodyPart(BodyPartType.Torso_Lower)
    end
    if not part and BodyPartType.UpperArm_L then
        part = bd:getBodyPart(BodyPartType.UpperArm_L)
    end

    if not part or not part.AddDamage then
        return false, nil
    end

    part:AddDamage(damage)
    return true, part
end

local function applyToxicHealthDamage(bd, damage)
    local amount = HTT.toNumber(damage, 0)
    if not bd or amount <= 0 then
        return false
    end

    local before = nil
    if bd.getOverallBodyHealth then
        before = HTT.toNumber(bd:getOverallBodyHealth(), nil)
    end

    if bd.ReduceGeneralHealth then
        bd:ReduceGeneralHealth(amount)

        if before ~= nil and bd.getOverallBodyHealth then
            local after = HTT.toNumber(bd:getOverallBodyHealth(), before)
            if after < before then
                syncToxicBodyDamage(bd)
                return true
            end
        elseif before == nil then
            syncToxicBodyDamage(bd)
            return true
        end
    end

    if bd.getOverallBodyHealth and bd.setOverallBodyHealth then
        local current = HTT.toNumber(before, bd:getOverallBodyHealth())
        current = HTT.toNumber(current, 100)
        local nextValue = math.max(0, current - amount)
        if nextValue < current then
            bd:setOverallBodyHealth(nextValue)
            syncToxicBodyDamage(bd)
            return true
        end
    end

    local ok, part = applyFallbackBodyPartDamage(bd, amount)
    if ok and part and syncBodyPart then
        syncBodyPart(part, 0xFFFFFFFFFFF)
    end
    return ok
end

local function isInsideEventRadius(player, state)
    local px = player:getX()
    local py = player:getY()
    local dx = px - state.centerX
    local dy = py - state.centerY
    local radius = HTT.toNumber(state.radius, HTT.Config.DefaultToxicRadius)
    local limit = radius * radius

    return (dx * dx + dy * dy) <= limit
end

local function decayToxicEffects(data, stats, bodyDamage, tickMinutes, decayMultiplier)
    local mul = HTT.toNumber(decayMultiplier, 1.0)
    if mul < 0 then
        mul = 0
    end

    if data.exposure > 0 then
        data.exposure = math.max(0, data.exposure - (EXPOSURE_DECAY_PER_MIN * tickMinutes * mul))
    end

    if data.panic > 0 then
        data.panic = math.max(0, data.panic - (PANIC_DECAY_PER_MIN * tickMinutes * mul))
        setStat(stats, "PANIC", data.panic)
    end

    if data.stress > 0 then
        data.stress = math.max(0, data.stress - (STRESS_DECAY_PER_MIN * tickMinutes * mul))
        setStat(stats, "STRESS", data.stress)
    end

    if data.sickness > 0 then
        if not isHardcoreToxicPreset() then
            local recoveryBoost = 1.0 + ((1.0 - math.min(EXPOSURE_MAX, data.exposure)) * 0.45)
            local sicknessDecay = SICKNESS_DECAY_PER_MIN * tickMinutes * mul * recoveryBoost
            data.sickness = math.max(0, data.sickness - sicknessDecay)
        end
        if CharacterStat and CharacterStat.FOOD_SICKNESS then
            setStat(stats, "FOOD_SICKNESS", data.sickness)
        else
            setStat(stats, "SICKNESS", data.sickness)
        end
        setBodyFoodSicknessLevel(bodyDamage, data.sickness)
    end
end

local function applyToxicToPlayer(player, state, fadeMul, tickMinutes)
    local data = getPlayerToxicData(player)
    local stats = player:getStats()
    local bd = player:getBodyDamage()

    if not isInsideEventRadius(player, state) then
        return
    end

    local sheltered = isPlayerShelteredFromAir(player)
    local indoorProtection = HTT.Config.ToxicIndoorProtection ~= false

    if sheltered and indoorProtection then
        -- Indoors should block active toxic damage buildup and let symptoms fade.
        decayToxicEffects(data, stats, bd, tickMinutes, 0.85)
        return
    end

    local indoorMul = 1.0
    if sheltered then
        if indoorProtection then
            indoorMul = HTT.toNumber(HTT.Config.ToxicIndoorExposureMultiplier, 0.40)
            if indoorMul < 0 then
                indoorMul = 0
            end
        end
    end

    local maskMul = getMaskMultiplier(player)
    if maskMul <= 0 then
        -- Full-face protection: no toxic buildup and gradual recovery while equipped.
        decayToxicEffects(data, stats, bd, tickMinutes, 0.85)
        return
    end

    local exposureGainPerMin = HTT.toNumber(HTT.Config.ToxicExposureGainPerMin, EXPOSURE_GAIN_PER_MIN)
    if exposureGainPerMin < 0 then
        exposureGainPerMin = 0
    end

    local gain = exposureGainPerMin
        * tickMinutes
        * maskMul
        * getUndergroundMultiplier(player)
        * indoorMul
        * fadeMul

    data.exposure = math.min(EXPOSURE_MAX, data.exposure + gain)
    local sicknessExposureThreshold = getSicknessExposureThreshold()
    local sicknessGainScale = getSicknessGainScale()

    if bd and data.exposure >= sicknessExposureThreshold then
        local sicknessFloor = data.exposure * 55.0
        raiseBodyFoodSicknessFloor(bd, sicknessFloor)
        if sicknessFloor > data.sickness then
            data.sickness = math.min(100, sicknessFloor)
            if CharacterStat and CharacterStat.FOOD_SICKNESS then
                setStat(stats, "FOOD_SICKNESS", data.sickness)
            else
                setStat(stats, "SICKNESS", data.sickness)
            end
        end
    end

    if data.exposure >= 0.3 then
        data.panic = math.min(100, data.panic + (PANIC_GAIN * tickMinutes))
        setStat(stats, "PANIC", data.panic)
    end
    if data.exposure >= 0.5 then
        data.stress = math.min(1, data.stress + (STRESS_GAIN * tickMinutes))
        setStat(stats, "STRESS", data.stress)
    end
    if data.exposure >= sicknessExposureThreshold then
        data.sickness = math.min(100, data.sickness + (SICKNESS_GAIN * sicknessGainScale * tickMinutes))
        if CharacterStat and CharacterStat.FOOD_SICKNESS then
            setStat(stats, "FOOD_SICKNESS", data.sickness)
        else
            setStat(stats, "SICKNESS", data.sickness)
        end
        setBodyFoodSicknessLevel(bd, data.sickness)
    end

    if bd and data.exposure >= PLAYER_DAMAGE_EXPOSURE_THRESHOLD then
        local exposure = math.min(1.0, math.max(0.0, data.exposure))
        local t = (exposure - PLAYER_DAMAGE_EXPOSURE_THRESHOLD) / (1.0 - PLAYER_DAMAGE_EXPOSURE_THRESHOLD)
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end

        local power = HTT.toNumber(HTT.Config.ToxicDamageCurvePower, TOXIC_DAMAGE_CURVE_POWER)
        if power < 0.2 then
            power = 0.2
        end
        local curve = t ^ power

        local dmgPerMin = HTT.toNumber(
            HTT.Config.ToxicDamagePerMinuteAtFullExposure,
            TOXIC_DAMAGE_PER_MIN_AT_FULL
        ) * curve

        local minPerMin = HTT.toNumber(HTT.Config.ToxicDamageMinPerMinute, TOXIC_DAMAGE_MIN_PER_MIN)
        if minPerMin < 0 then
            minPerMin = 0
        end
        if dmgPerMin < minPerMin then
            dmgPerMin = minPerMin
        end

        local damage = dmgPerMin * tickMinutes * fadeMul
        if damage > 0 then
            applyToxicHealthDamage(bd, damage)
        end
    end

    if bd and data.exposure >= 0.9 then
        local extraPerMin = HTT.toNumber(
            HTT.Config.ToxicExtraDamagePerMinuteOnMaxExposure,
            TOXIC_EXTRA_MAX_PER_MIN
        )
        if extraPerMin < 0 then
            extraPerMin = 0
        end
        local extra = extraPerMin * tickMinutes * fadeMul
        if extra > 0 then
            applyToxicHealthDamage(bd, extra)
        end
    end
end

local function getZombieResistance(zombie)
    local md = zombie:getModData()
    if not md.HTT_ToxicResistance then
        md.HTT_ToxicResistance = ZombRandFloat(RESISTANCE_MIN, RESISTANCE_MAX)
    end
    return md.HTT_ToxicResistance
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

local function damageNearbyZombies(state, fadeMul, tickMinutes)
    local cell = getCell()
    if not cell then
        return
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return
    end

    local radius = HTT.toNumber(state.radius, HTT.Config.DefaultToxicRadius)
    local limit = radius * radius
    local damagePerMinute = HTT.toNumber(
        HTT.Config.ToxicDamagePerMinuteAtFullExposure,
        TOXIC_DAMAGE_PER_MIN_AT_FULL
    )
    if damagePerMinute < 0 then
        damagePerMinute = 0
    end
    local affected = 0
    local damaged = 0
    local killed = 0
    local killer = nil
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        local bestDist = nil
        local cx = HTT.toNumber(state.centerX, 0)
        local cy = HTT.toNumber(state.centerY, 0)
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player and not player:isDead() then
                local dx = player:getX() - cx
                local dy = player:getY() - cy
                local distSq = dx * dx + dy * dy
                if not bestDist or distSq < bestDist then
                    bestDist = distSq
                    killer = player
                end
            end
        end
    elseif getPlayer then
        local localPlayer = getPlayer()
        if localPlayer and not localPlayer:isDead() then
            killer = localPlayer
        end
    end

    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dx = zombie:getX() - state.centerX
            local dy = zombie:getY() - state.centerY
            if (dx * dx + dy * dy) <= limit then
                affected = affected + 1
                local md = zombie:getModData()
                local resistance = getZombieResistance(zombie)
                local damage = (damagePerMinute * tickMinutes * fadeMul) / resistance
                local trackedHealth = HTT.toNumber(md.HTT_ToxicVirtualHealth, nil)
                if trackedHealth == nil or trackedHealth <= 0 then
                    trackedHealth = 1.0
                    md.HTT_ToxicVirtualHealth = trackedHealth
                end
                local nextHealth = trackedHealth - damage
                md.HTT_ToxicVirtualHealth = math.max(0, nextHealth)
                if nextHealth <= 0.05 then
                    HTT.log(string.format(
                        "Toxic zombie virtualHP=%.3f damage=%.3f next=%.3f",
                        trackedHealth,
                        damage,
                        nextHealth
                    ))
                    if killZombieSafe(zombie, killer) then
                        md.HTT_ToxicVirtualHealth = nil
                        killed = killed + 1
                    end
                else
                    local appliedHealth = math.max(0.06, nextHealth)
                    if zombie.setHealth then
                        zombie:setHealth(appliedHealth)
                    end
                    local bd = zombie.getBodyDamage and zombie:getBodyDamage() or nil
                    if bd and bd.setOverallBodyHealth then
                        pcall(function()
                            bd:setOverallBodyHealth(appliedHealth * 100.0)
                        end)
                    end
                    damaged = damaged + 1
                end
            end
        end
    end

    if affected > 0 then
        HTT.log(string.format(
            "Toxic zombie tick affected=%d damaged=%d kills=%d center=(%.1f, %.1f)",
            affected,
            damaged,
            killed,
            HTT.toNumber(state.centerX, 0),
            HTT.toNumber(state.centerY, 0)
        ))
    end
end

local function attractNearbyZombies(state)
    if not addSound then
        return
    end

    local attractRadius = math.max(
        ATTRACT_RADIUS,
        math.floor(HTT.toNumber(state.radius, HTT.Config.DefaultToxicRadius) + 30)
    )
    local attractVolume = ATTRACT_VOLUME

    local cx = math.floor(HTT.toNumber(state.centerX, 0))
    local cy = math.floor(HTT.toNumber(state.centerY, 0))
    local cz = math.floor(HTT.toNumber(state.centerZ, 0))
    addSound(nil, cx, cy, cz, attractRadius, attractVolume)

    local attractedPlayers = 0
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player and not player:isDead() then
                local px = math.floor(player:getX())
                local py = math.floor(player:getY())
                local pz = math.floor(player:getZ())
                addSound(nil, px, py, pz, attractRadius, attractVolume)
                attractedPlayers = attractedPlayers + 1
            end
        end
    end

    if attractedPlayers == 0 and getPlayer then
        local player = getPlayer()
        if player and not player:isDead() then
            local px = math.floor(player:getX())
            local py = math.floor(player:getY())
            local pz = math.floor(player:getZ())
            addSound(nil, px, py, pz, attractRadius, attractVolume)
        end
    end
end

local function getToxicSoundRadius(state)
    local base = HTT.toNumber(state and state.radius, HTT.Config.DefaultSoundRadius)
    local r = math.max(base + 80, HTT.Config.DefaultSoundRadius + 30)
    return math.floor(r)
end

local function getToxicAmbientRepeatHours()
    local repeatMinutes = HTT.toNumber(HTT.Config.ToxicAmbientRepeatMinutes, 2)
    if repeatMinutes <= 0 then
        repeatMinutes = 2
    end

    local repeatSeconds = repeatMinutes * 60.0
    if repeatSeconds < TOXIC_ACTIVE_SOUND_MIN_REPEAT_SECONDS then
        repeatSeconds = TOXIC_ACTIVE_SOUND_MIN_REPEAT_SECONDS
    end

    if HTT.secondsToWorldHours then
        local worldHours = HTT.secondsToWorldHours(repeatSeconds, repeatSeconds)
        if worldHours and worldHours > 0 then
            return worldHours
        end
    end

    return repeatSeconds / 3600.0
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
    if not state or not state.active or state.eventId ~= "toxic" then
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

    local dx = nx - oldX
    local dy = ny - oldY
    if (dx * dx + dy * dy) >= 4 then
        HTT.log(string.format(
            "Toxic center follow moved to (%.1f, %.1f, %.1f) follow=%s",
            nx, ny, nz, tostring(state.followOnlineId)
        ))
    end

    return true
end

local function countZombiesNearCenter(state, radius)
    local cell = getCell()
    if not cell then
        return 0
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return 0
    end

    local nearRadius = HTT.toNumber(radius, HTT.Config.ToxicNearZombieRadius)
    local limit = nearRadius * nearRadius
    local count = 0

    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dx = zombie:getX() - state.centerX
            local dy = zombie:getY() - state.centerY
            if (dx * dx + dy * dy) <= limit then
                count = count + 1
            end
        end
    end

    return count
end

local function updateToxicPhase(state)
    if not state.active then
        return
    end

    if state.eventId ~= "toxic" then
        return
    end

    local phase = tostring(state.toxicPhase or "")
    if phase ~= "approach" then
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local earliestHour = HTT.toNumber(state.toxicPhaseEarliestHour, now)
    local forceHour = HTT.toNumber(state.toxicPhaseForceHour, earliestHour)
    local nearRadius = HTT.toNumber(HTT.Config.ToxicNearZombieRadius, 26)
    local nearCountNeeded = HTT.toNumber(HTT.Config.ToxicNearZombieCount, 8)
    local nearCount = countZombiesNearCenter(state, nearRadius)

    local canActivate = now >= earliestHour and nearCount >= nearCountNeeded
    local forceActivate = now >= forceHour

    if not canActivate and not forceActivate then
        return
    end

    state.toxicPhase = "active"
    state.toxicPhaseStartHour = now

    state.toxicNextAmbientHour = now + getToxicAmbientRepeatHours()

    if HTT.Server and HTT.Server.broadcastEventState then
        HTT.Server.broadcastEventState()
    end

    local def = HTT.getEventDefinition("toxic")
    local activeSound = def and (def.activeSound or def.loopSound) or nil
    if activeSound
        and HTT.Server
        and HTT.Server.broadcastSound
        and not (HTT.shouldBlockEventsForSleep and HTT.shouldBlockEventsForSleep())
    then
        local soundRadius = getToxicSoundRadius(state)
        HTT.Server.broadcastSound(
            activeSound,
            state.centerX,
            state.centerY,
            state.centerZ,
            soundRadius,
            {
                volumeMul = TOXIC_ACTIVE_SOUND_VOLUME_MUL,
                eventId = state.eventId,
                attachToFollowPlayer = true,
                followOnlineId = state.followOnlineId,
            }
        )
        HTT.log("Toxic phase sound active-start broadcast radius=" .. tostring(soundRadius))
    end

    HTT.log(string.format(
        "Toxic phase changed approach -> active (nearZombies=%d/%d)",
        nearCount,
        nearCountNeeded
    ))
end

local function playAmbientLoopIfNeeded(state)
    if not state.active then
        return
    end

    if tostring(state.toxicPhase or "") ~= "active" then
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local nextHour = HTT.toNumber(state.toxicNextAmbientHour, 0)
    if nextHour > 0 and now < nextHour then
        return
    end

    state.toxicNextAmbientHour = now + getToxicAmbientRepeatHours()

    if HTT.shouldBlockEventsForSleep and HTT.shouldBlockEventsForSleep() then
        return
    end

    local def = HTT.getEventDefinition("toxic")
    local activeSound = def and (def.activeSound or def.loopSound) or nil
    if activeSound and HTT.Server and HTT.Server.broadcastSound then
        local soundRadius = getToxicSoundRadius(state)
        HTT.Server.broadcastSound(
            activeSound,
            state.centerX,
            state.centerY,
            state.centerZ,
            soundRadius,
            {
                volumeMul = TOXIC_ACTIVE_SOUND_VOLUME_MUL,
                eventId = state.eventId,
                attachToFollowPlayer = true,
                followOnlineId = state.followOnlineId,
            }
        )
        HTT.log("Toxic phase sound ambient-loop broadcast radius=" .. tostring(soundRadius))
    end
end

local function getFadeMultiplier(state, tickMinutes)
    if state.active then
        return 1.0
    end

    if state.fadeMinutes <= 0 then
        return 0
    end

    local fadeMul = state.fadeMinutes / HTT.Config.ToxicFadeMinutes
    state.fadeMinutes = math.max(0, state.fadeMinutes - tickMinutes)

    if state.fadeMinutes <= 0 and HTT.Server and HTT.Server.clearFinishedToxicFade then
        HTT.Server.clearFinishedToxicFade()
    end

    return fadeMul
end

local decayLingeringToxicEffects

local function toxicTick()
    if not HTT.Server or not HTT.Server.state then
        return
    end

    local state = HTT.Server.state
    if state.eventId ~= "toxic" then
        return
    end

    if not state.active and state.fadeMinutes <= 0 then
        return
    end

    if state.active then
        updateDynamicCenter(state)
    end

    if state.active and tostring(state.toxicPhase or "") == "approach" then
        attractNearbyZombies(state)
        updateToxicPhase(state)
    end

    local tickSeconds = HTT.toNumber(HTT.Config.ToxicTickSeconds, 60)
    if tickSeconds < 1 then
        tickSeconds = 1
    end
    local tickMinutes = tickSeconds / 60.0

    local fadeMul = getFadeMultiplier(state, tickMinutes)
    if fadeMul <= 0 then
        return
    end

    if state.active then
        local phase = tostring(state.toxicPhase or "")
        if phase ~= "active" then
            -- Approach/rotor phase should not apply toxic damage/sickness.
            attractNearbyZombies(state)
            playAmbientLoopIfNeeded(state)
            return
        end

        local players = getOnlinePlayers and getOnlinePlayers() or nil
        local processedAnyPlayer = false

        if players and players:size() > 0 then
            for i = 0, players:size() - 1 do
                local player = players:get(i)
                if player and not player:isDead() then
                    applyToxicToPlayer(player, state, fadeMul, tickMinutes)
                    processedAnyPlayer = true
                end
            end
        end

        if not processedAnyPlayer and getPlayer then
            local localPlayer = getPlayer()
            if localPlayer and not localPlayer:isDead() then
                applyToxicToPlayer(localPlayer, state, fadeMul, tickMinutes)
                processedAnyPlayer = true
            end
        end

        damageNearbyZombies(state, fadeMul, tickMinutes)

        attractNearbyZombies(state)
        playAmbientLoopIfNeeded(state)
        return
    end

    -- Event ended: fade is visual/audio only; recovery starts now and is slow.
    decayLingeringToxicEffects(tickMinutes)
end

local function decayLingeringToxicPlayer(player, tickMinutes)
    if not player or player:isDead() then
        return false
    end

    local data = getPlayerToxicData(player)
    if data.exposure <= 0 and data.panic <= 0 and data.stress <= 0 and data.sickness <= 0 then
        return false
    end

    local stats = player:getStats()
    local bd = player:getBodyDamage()
    decayToxicEffects(data, stats, bd, tickMinutes, LINGERING_RECOVERY_DECAY_MULTIPLIER)
    return true
end

decayLingeringToxicEffects = function(tickMinutes)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local processedAnyPlayer = false

    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if decayLingeringToxicPlayer(player, tickMinutes) then
                processedAnyPlayer = true
            end
        end
    end

    if not processedAnyPlayer and getPlayer then
        local localPlayer = getPlayer()
        decayLingeringToxicPlayer(localPlayer, tickMinutes)
    end
end

local function toxicTickDriver()
    if not HTT.Server or not HTT.Server.state then
        nextToxicTickHour = 0
        return
    end

    local state = HTT.Server.state

    local now = getGameTime():getWorldAgeHours()
    local tickSeconds = HTT.toNumber(HTT.Config.ToxicTickSeconds, 60)
    if tickSeconds < 1 then
        tickSeconds = 1
    end
    local tickHours = tickSeconds / 3600.0

    if nextToxicTickHour <= 0 then
        nextToxicTickHour = now
    end

    local activeToxicEvent = state.active and state.eventId == "toxic"
    local pausedForVanilla = activeToxicEvent
        and HTT.Server.updateVanillaPauseState
        and HTT.Server.updateVanillaPauseState(now)
        or false
    if pausedForVanilla then
        local lastPauseHour = HTT.toNumber(HTT.Server._toxicPauseLastHour, now)
        local delta = math.max(0, now - lastPauseHour)
        if nextToxicTickHour > 0 and delta > 0.000001 then
            nextToxicTickHour = nextToxicTickHour + delta
        end
        HTT.Server._toxicPauseLastHour = now
        return
    end
    HTT.Server._toxicPauseLastHour = nil

    if now + 0.000001 < nextToxicTickHour then
        return
    end

    local eventIsToxic = state.eventId == "toxic"
    local eventRunning = state.active or HTT.toNumber(state.fadeMinutes, 0) > 0
    if eventIsToxic and eventRunning then
        toxicTick()
    else
        decayLingeringToxicEffects(tickSeconds / 60.0)
    end
    nextToxicTickHour = now + tickHours
end

local toxicTickHooked = registerEvent("OnTick", toxicTickDriver)
if not toxicTickHooked then
    registerEvent("EveryOneMinute", toxicTickDriver)
end

registerEvent("OnGameStart", function()
    HTT.log("Server toxic system loaded (hook=" .. tostring(toxicTickHooked and "OnTick" or "EveryOneMinute") .. ")")
end)
