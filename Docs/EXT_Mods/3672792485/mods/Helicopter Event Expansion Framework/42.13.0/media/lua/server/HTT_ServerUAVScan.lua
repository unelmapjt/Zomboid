require "HTT_Core"
require "HTT_ServerEventManager"

HTT.ServerUAVScan = HTT.ServerUAVScan or {}

if HTT._serverUAVScanLoaded then
    return
end
HTT._serverUAVScanLoaded = true

local UAV_APPROACH_SECONDS = 30.0
local UAV_SCAN_INTERVAL_SECONDS = 12.0
local UAV_FOLLOW_SYNC_SECONDS = 2.5
local UW_RF_UUID = "UW-RF-1122"
local UW_RF_FREQ = 112200

local runtime = {
    eventStartHour = 0,
    actionHour = 0,
    nextScanHour = 0,
    nextCenterSyncHour = 0,
    scanIndex = 0,
}

local function resetRuntime()
    runtime.eventStartHour = 0
    runtime.actionHour = 0
    runtime.nextScanHour = 0
    runtime.nextCenterSyncHour = 0
    runtime.scanIndex = 0
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

local function ensureUWRadioChannel(scriptManager)
    if not DynamicRadio then
        return nil
    end

    DynamicRadio.channels = DynamicRadio.channels or {}
    DynamicRadio.cache = DynamicRadio.cache or {}

    if DynamicRadio.cache[UW_RF_UUID] then
        return DynamicRadio.cache[UW_RF_UUID]
    end

    local found = false
    for i = 1, #DynamicRadio.channels do
        local channel = DynamicRadio.channels[i]
        if channel and channel.uuid == UW_RF_UUID then
            found = true
            break
        end
    end

    if not found then
        table.insert(DynamicRadio.channels, {
            name = "Unseasonal Weather Network",
            freq = UW_RF_FREQ,
            category = "Emergency",
            uuid = UW_RF_UUID,
            register = true,
        })
    end

    if DynamicRadioChannel and DynamicRadioChannel.new then
        local category = ChannelCategory and ChannelCategory.Emergency or ChannelCategory.Other
        local dynamicChannel = DynamicRadioChannel.new("Unseasonal Weather Network", UW_RF_FREQ, category, UW_RF_UUID)
        if dynamicChannel then
            if scriptManager and scriptManager.AddChannel then
                scriptManager:AddChannel(dynamicChannel, false)
            end
            DynamicRadio.cache[UW_RF_UUID] = dynamicChannel
            return dynamicChannel
        end
    end

    return DynamicRadio.cache[UW_RF_UUID]
end

local function sendUWRadioMessage(text)
    local message = tostring(text or "")
    if message == "" then
        return false
    end

    local channel = ensureUWRadioChannel()
    if not channel or not RadioBroadCast or not RadioLine then
        return false
    end

    local line = RadioLine.new(message, 150, 150, 150)
    if not line then
        return false
    end
    if line.setPriority then
        pcall(function()
            line:setPriority(5)
        end)
    end
    if line.setLoop then
        pcall(function()
            line:setLoop(false)
        end)
    end

    local label = "HTT UAV Scan " .. tostring(ZombRand(1, 99999))
    local broadcast = RadioBroadCast.new(label, -1, -1)
    if not broadcast then
        return false
    end
    broadcast:AddRadioLine(line)
    channel:setAiringBroadcast(broadcast)
    return true
end

local function isAliveZombie(obj)
    if not obj then
        return false
    end

    local isZombie = false
    if instanceof then
        local ok, result = pcall(function()
            return instanceof(obj, "IsoZombie")
        end)
        if ok and result == true then
            isZombie = true
        end
    end

    if not isZombie and obj.getObjectName then
        local okName, objectName = pcall(function()
            return obj:getObjectName()
        end)
        if okName and tostring(objectName or "") == "IsoZombie" then
            isZombie = true
        end
    end

    if not isZombie then
        return false
    end

    if obj.isDead then
        local okDead, dead = pcall(function()
            return obj:isDead()
        end)
        if okDead and dead == true then
            return false
        end
    end

    return true
end

local function countZombiesInRadius(cx, cy, cz, radius)
    local cell = getCell and getCell() or nil
    if not cell or not cell.getObjectList then
        return 0
    end

    local objectList = cell:getObjectList()
    if not objectList then
        return 0
    end

    local radiusSq = radius * radius
    local total = 0
    for i = 0, objectList:size() - 1 do
        local obj = objectList:get(i)
        if isAliveZombie(obj) then
            local zx = HTT.toNumber(obj.getX and obj:getX() or nil, nil)
            local zy = HTT.toNumber(obj.getY and obj:getY() or nil, nil)
            local zz = HTT.toNumber(obj.getZ and obj:getZ() or nil, cz)
            if zx ~= nil and zy ~= nil then
                local dz = math.abs(zz - cz)
                if dz <= 2 then
                    local dx = zx - cx
                    local dy = zy - cy
                    if (dx * dx + dy * dy) <= radiusSq then
                        total = total + 1
                    end
                end
            end
        end
    end
    return total
end

local function classifyDensity(zombieCount)
    local count = math.max(0, HTT.toNumber(zombieCount, 0))
    if count <= 10 then
        return "LOW"
    end
    if count <= 30 then
        return "MODERATE"
    end
    if count <= 60 then
        return "HIGH"
    end
    return "CRITICAL"
end

local function resolveFollowPlayer(state)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local followOnlineId = state and state.followOnlineId or nil

    if players and players:size() > 0 then
        if followOnlineId ~= nil then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p and not p:isDead() and p.getOnlineID and p:getOnlineID() == followOnlineId then
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
                if bestDist == nil or distSq < bestDist then
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

local function updateDynamicCenter(state, now)
    if runtime.nextCenterSyncHour > 0 and now < runtime.nextCenterSyncHour then
        return
    end
    runtime.nextCenterSyncHour = now + secondsToWorldHoursSafe(
        UAV_FOLLOW_SYNC_SECONDS,
        UAV_FOLLOW_SYNC_SECONDS
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

local function broadcastApproachSound(state, eventDef)
    if not state or not eventDef or not eventDef.startSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 18,
        HTT.Config.DefaultSoundRadius + 12
    )
    HTT.Server.broadcastSound(
        eventDef.startSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "uav_scan_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function broadcastScanSound(state, eventDef)
    if not state or not eventDef or not eventDef.actionSound then
        return
    end
    if not HTT.Server or not HTT.Server.broadcastSound then
        return
    end

    local soundRadius = math.max(
        HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius) + 18,
        HTT.Config.DefaultSoundRadius + 12
    )
    HTT.Server.broadcastSound(
        eventDef.actionSound,
        state.centerX,
        state.centerY,
        state.centerZ,
        soundRadius,
        {
            eventId = "uav_scan_event",
            attachToFollowPlayer = true,
            followOnlineId = state and state.followOnlineId or nil,
        }
    )
end

local function runScanPulse(state, eventDef, now)
    runtime.scanIndex = runtime.scanIndex + 1

    local radius = math.max(10, HTT.toNumber(state.radius, 30))
    local cx = HTT.toNumber(state.centerX, 0)
    local cy = HTT.toNumber(state.centerY, 0)
    local cz = HTT.toNumber(state.centerZ, 0)
    local zombieCount = countZombiesInRadius(cx, cy, cz, radius)
    local density = classifyDensity(zombieCount)
    local message = string.format("Sector density: %s. (%d contacts)", density, zombieCount)

    broadcastScanSound(state, eventDef)
    local radioSent = sendUWRadioMessage(message)

    runtime.nextScanHour = now + secondsToWorldHoursSafe(
        UAV_SCAN_INTERVAL_SECONDS,
        UAV_SCAN_INTERVAL_SECONDS
    )

    HTT.log(string.format(
        "UAV scan pulse index=%d density=%s zombies=%d radius=%.1f radioSent=%s",
        runtime.scanIndex,
        density,
        zombieCount,
        radius,
        tostring(radioSent)
    ))
end

local function uavScanTick()
    if not HTT.Server or not HTT.Server.state then
        resetRuntime()
        return
    end

    local state = HTT.Server.state
    if not state.active or state.eventId ~= "uav_scan_event" then
        resetRuntime()
        return
    end

    local now = getNowWorldHourSafe()
    local pausedForVanilla = HTT.Server.updateVanillaPauseState and HTT.Server.updateVanillaPauseState(now) or false
    if pausedForVanilla then
        if HTT.Server.delayRuntimeHoursForVanillaPause then
            HTT.Server.delayRuntimeHoursForVanillaPause(
                runtime,
                { "actionHour", "nextScanHour", "nextCenterSyncHour" },
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

    local eventDef = HTT.getEventDefinition("uav_scan_event")
    if not eventDef then
        return
    end

    local eventStart = HTT.toNumber(state.startHour, now)
    if runtime.eventStartHour ~= eventStart then
        runtime.eventStartHour = eventStart
        runtime.actionHour = eventStart + secondsToWorldHoursSafe(
            UAV_APPROACH_SECONDS,
            UAV_APPROACH_SECONDS
        )
        runtime.nextScanHour = runtime.actionHour
        runtime.nextCenterSyncHour = 0
        runtime.scanIndex = 0
        broadcastApproachSound(state, eventDef)
    end

    updateDynamicCenter(state, now)

    if now < HTT.toNumber(runtime.actionHour, now) then
        return
    end

    if now >= HTT.toNumber(runtime.nextScanHour, now) then
        runScanPulse(state, eventDef, now)
    end
end

local uavTickHooked = registerEvent("OnTick", uavScanTick)
if not uavTickHooked then
    registerEvent("EveryOneMinute", uavScanTick)
end

registerEvent("OnLoadRadioScripts", function(scriptManager)
    ensureUWRadioChannel(scriptManager)
end)

registerEvent("OnGameStart", function()
    ensureUWRadioChannel()
    HTT.log(
        "Server UAV scan system loaded (hook="
            .. tostring(uavTickHooked and "OnTick" or "EveryOneMinute")
            .. ")"
    )
end)
