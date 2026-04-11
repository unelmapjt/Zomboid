require "HTT_Core"
require "HTT_ServerEventManager"

if HTT._serverVanillaHookLoaded then
    return
end
HTT._serverVanillaHookLoaded = true

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

local VANILLA_RESET_GRACE_SECONDS = 5.0
local VANILLA_RESET_GRACE_HOURS = VANILLA_RESET_GRACE_SECONDS / 3600.0
local vanillaWasActive = false
local vanillaInactiveSinceHour = nil

local function getCurrentWorldHour()
    local gt = getGameTime and getGameTime() or nil
    if not gt or not gt.getWorldAgeHours then
        return 0
    end

    local ok, worldAgeHours = pcall(gt.getWorldAgeHours, gt)
    if not ok then
        return 0
    end

    return HTT.toNumber(worldAgeHours, 0)
end

local function shouldTriggerFromVanilla()
    if HTT.isModEnabled and not HTT.isModEnabled() then
        return false
    end

    if HTT.Config.EnableVanillaHelicopterHook ~= true then
        return false
    end

    local chance = HTT.toNumber(HTT.Config.VanillaHookTriggerChance, 100)
    if chance <= 0 then
        return false
    end

    return ZombRandFloat(0, 100) <= chance
end

local function onVanillaHelicopterStarted()
    if not HTT.Server or not HTT.Server.startEvent then
        return
    end

    if HTT.Server.state and HTT.Server.state.active then
        HTT.log("Vanilla helicopter trigger skipped: HTT event already active.")
        return
    end

    if not shouldTriggerFromVanilla() then
        HTT.log("Vanilla helicopter trigger skipped by sandbox chance/config.")
        return
    end

    local eventId = HTT.pickWeightedVanillaEventId and HTT.pickWeightedVanillaEventId() or HTT.Config.DefaultEventId
    local ok, err = HTT.Server.startEvent(eventId, "vanilla", nil, nil, nil, nil, nil, false, nil)
    if ok then
        HTT.log("Vanilla helicopter trigger started HTT event: " .. tostring(eventId))
    else
        HTT.log("Vanilla helicopter trigger failed: " .. tostring(err))
    end
end

local function monitorVanillaHelicopter()
    local active = HTT.Server and HTT.Server.isVanillaHelicopterActive and HTT.Server.isVanillaHelicopterActive() or false
    if active then
        vanillaInactiveSinceHour = nil
        if not vanillaWasActive then
            vanillaWasActive = true
            onVanillaHelicopterStarted()
        end
        return
    end

    if not vanillaWasActive then
        vanillaInactiveSinceHour = nil
        return
    end

    local now = getCurrentWorldHour()
    if vanillaInactiveSinceHour == nil then
        vanillaInactiveSinceHour = now
        return
    end

    if math.max(0, now - vanillaInactiveSinceHour) >= VANILLA_RESET_GRACE_HOURS then
        vanillaWasActive = false
        vanillaInactiveSinceHour = nil
        HTT.log("Vanilla helicopter trigger latch reset after helicopter became inactive.")
    end
end

local hookRegistered = registerEvent("OnTick", monitorVanillaHelicopter)
if not hookRegistered then
    registerEvent("EveryOneMinute", monitorVanillaHelicopter)
end

registerEvent("OnGameStart", function()
    HTT.log(
        "Vanilla helicopter trigger hook loaded (enabled="
            .. tostring(HTT.Config.EnableVanillaHelicopterHook)
            .. ", chance="
            .. tostring(HTT.toNumber(HTT.Config.VanillaHookTriggerChance, 100))
            .. "%)"
    )
end)
