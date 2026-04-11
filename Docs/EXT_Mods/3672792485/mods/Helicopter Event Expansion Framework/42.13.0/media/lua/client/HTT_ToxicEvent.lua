require "HTT_Main"
require "HTT_ToxicFog"
require "ISUI/ISUIElement"

HTT = HTT or {}

if HTT._clientToxicLoaded then
    return
end
HTT._clientToxicLoaded = true
HTT._seenSoundSids = HTT._seenSoundSids or {}
HTT._seenSoundSidCount = HTT._seenSoundSidCount or 0
HTT._directionalIndicators = HTT._directionalIndicators or {}
HTT._surveillanceScanOverlay = HTT._surveillanceScanOverlay or nil
HTT._clientSoundLogState = HTT._clientSoundLogState or {}
HTT._pendingSoundCommands = HTT._pendingSoundCommands or {}
HTT._surveillanceScanState = HTT._surveillanceScanState or {
    eventStartHour = nil,
    nextPulseHour = 0,
    triggeredForStart = false,
}
HTT._surveillanceScanLastTriggerHour = HTT._surveillanceScanLastTriggerHour or nil
HTT._clientPresentationDrawHooked = HTT._clientPresentationDrawHooked == true
HTT._clientPresentationDrawHook = HTT._clientPresentationDrawHook or "none"
HTT._clientPresentationDrawHost = HTT._clientPresentationDrawHost or nil
HTT._clientPresentationDrawHostWarned = HTT._clientPresentationDrawHostWarned == true

local SURVEILLANCE_SCAN_PULSE_COUNT = 3
local SURVEILLANCE_SCAN_PULSE_ON_SECONDS = 0.16
local SURVEILLANCE_SCAN_PULSE_OFF_SECONDS = 0.10
local SURVEILLANCE_SCAN_OVERLAY_ALPHA = 0.18
local SURVEILLANCE_SCAN_BAR_ALPHA = 0.28
local SURVEILLANCE_SCAN_ACTION_DELAY_SECONDS = 30.0
local SURVEILLANCE_SCAN_TRIGGER_FROM_EVENT_STATE = true
local SURVEILLANCE_SCAN_TRIGGER_COOLDOWN_SECONDS = 0.80
local CLIENT_PENDING_SOUND_LIMIT = 48
local CLIENT_PENDING_SOUND_TTL_MS = 20000

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

local function clamp01(value)
    local n = HTT.toNumber(value, 0)
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function logClientSoundState(soundId, played, route)
    if not HTT.log then
        return
    end

    local key = tostring(soundId or "")
    if key == "" then
        return
    end

    local state = HTT._clientSoundLogState[key]
    if not state then
        state = {
            failedLogged = false,
            playedLogged = false,
        }
        HTT._clientSoundLogState[key] = state
    end

    if played then
        local routeKey = tostring(route or "")
        if not state.playedLogged or state.lastRoute ~= routeKey then
            if routeKey ~= "" then
                HTT.log("Client sound played: " .. key .. " via " .. routeKey)
            else
                HTT.log("Client sound played: " .. key)
            end
            state.playedLogged = true
        end
        state.lastRoute = routeKey
        state.failedLogged = false
        return
    end

    if not state.failedLogged then
        HTT.log("Client sound failed: " .. key)
        state.failedLogged = true
    end
    state.playedLogged = false
    state.lastRoute = nil
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

local function getTimestampMsSafe()
    if getTimestampMs then
        local ok, value = pcall(function()
            return getTimestampMs()
        end)
        if ok and value then
            return HTT.toNumber(value, 0)
        end
    end
    if getTimeInMillis then
        local ok, value = pcall(function()
            return getTimeInMillis()
        end)
        if ok and value then
            return HTT.toNumber(value, 0)
        end
    end

    return math.floor(getWorldAgeHoursSafe() * 3600000)
end

local function copyArgsTable(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for k, v in pairs(source) do
        if k ~= "_queuedAtMs" and k ~= "_internalReplay" then
            copy[k] = v
        end
    end

    return copy
end

local function trimPendingSoundQueue()
    while #HTT._pendingSoundCommands > CLIENT_PENDING_SOUND_LIMIT do
        table.remove(HTT._pendingSoundCommands, 1)
    end
end

local function queuePendingSoundCommand(args)
    if type(args) ~= "table" then
        return false
    end

    local queued = copyArgsTable(args)
    queued._queuedAtMs = getTimestampMsSafe()

    local sid = HTT.toNumber(queued.sid, nil)
    if sid ~= nil then
        for i = 1, #HTT._pendingSoundCommands do
            local existing = HTT._pendingSoundCommands[i]
            if HTT.toNumber(existing and existing.sid, nil) == sid then
                HTT._pendingSoundCommands[i] = queued
                return true
            end
        end
    end

    table.insert(HTT._pendingSoundCommands, queued)
    trimPendingSoundQueue()
    return true
end

local function markSoundSidSeen(sid)
    if sid == nil then
        return true
    end
    if HTT._seenSoundSids[sid] then
        return false
    end

    HTT._seenSoundSids[sid] = true
    HTT._seenSoundSidCount = HTT._seenSoundSidCount + 1
    if HTT._seenSoundSidCount > 512 then
        HTT._seenSoundSids = {}
        HTT._seenSoundSidCount = 0
    end

    return true
end

local function flushPendingSoundCommands()
    if HTT.isTimeFastForward and HTT.isTimeFastForward() then
        return
    end

    if not getPlayer or not getPlayer() then
        return
    end

    local pending = HTT._pendingSoundCommands
    if type(pending) ~= "table" or #pending <= 0 then
        return
    end

    HTT._pendingSoundCommands = {}

    local nowMs = getTimestampMsSafe()
    for i = 1, #pending do
        local queued = pending[i]
        if type(queued) == "table" then
            local queuedAtMs = HTT.toNumber(queued._queuedAtMs, nowMs)
            if (nowMs - queuedAtMs) <= CLIENT_PENDING_SOUND_TTL_MS then
                queued._queuedAtMs = nil
                queued._internalReplay = true
                HTT.ClientPlaySoundNearPlayer(queued)
            end
        end
    end
end

local function worldToScreen(x, y, z)
    if not IsoUtils or not IsoUtils.XToScreen or not IsoUtils.YToScreen then
        return nil, nil
    end

    local sx = IsoUtils.XToScreen(x, y, z, 0)
    local sy = IsoUtils.YToScreen(x, y, z, 0)
    if sx ~= nil and sy ~= nil and getCameraOffX and getCameraOffY then
        sx = sx - getCameraOffX()
        sy = sy - getCameraOffY()
    end
    return sx, sy
end

local function sanitizeScreenPosition(x, y, screenW, screenH)
    local sx = HTT.toNumber(x, nil)
    local sy = HTT.toNumber(y, nil)
    if sx == nil or sy == nil then
        return nil, nil
    end

    if sx < -screenW or sx > (screenW * 2) or sy < -screenH or sy > (screenH * 2) then
        return nil, nil
    end

    return math.floor(sx), math.floor(sy)
end

local function getPlayerScreenPosition(screenW, screenH)
    local centerX = math.floor(screenW * 0.5)
    local centerY = math.floor(screenH * 0.5)
    local player = getPlayer and getPlayer() or nil
    if not player then
        return centerX, centerY
    end

    if player.getScreenX and player.getScreenY then
        local okX, px = pcall(function()
            return player:getScreenX()
        end)
        local okY, py = pcall(function()
            return player:getScreenY()
        end)
        if okX and okY then
            local sx, sy = sanitizeScreenPosition(px, py, screenW, screenH)
            if sx ~= nil and sy ~= nil then
                return sx, sy
            end
        end
    end

    local sx, sy = worldToScreen(player:getX(), player:getY(), player:getZ())
    sx, sy = sanitizeScreenPosition(sx, sy, screenW, screenH)
    if sx ~= nil and sy ~= nil then
        return sx, sy
    end

    return centerX, centerY
end

local function configureClientPresentationDrawHost(host)
    if not host then
        return
    end

    local passthrough = function()
        return false
    end

    host.onMouseDown = passthrough
    host.onMouseUp = passthrough
    host.onMouseUpOutside = passthrough
    host.onRightMouseDown = passthrough
    host.onRightMouseUp = passthrough
    host.onRightMouseUpOutside = passthrough
    host.onMouseMove = passthrough
    host.onMouseMoveOutside = passthrough
    host.onMouseWheel = passthrough
    host.onMouseDownOutside = passthrough
    host.onRightMouseDownOutside = passthrough

    pcall(function()
        if host.setCapture then
            host:setCapture(false)
        end
    end)

    pcall(function()
        if host.setConsumeMouseEvents then
            host:setConsumeMouseEvents(false)
        end
    end)

    pcall(function()
        if host.setEnabled then
            host:setEnabled(false)
        end
    end)
end

local function getClientPresentationDrawHost()
    local host = HTT._clientPresentationDrawHost
    if host and host.javaObject then
        pcall(function()
            host:setX(0)
            host:setY(0)
            host:setWidth(1)
            host:setHeight(1)
            host:setVisible(true)
            if host.setAlwaysOnTop then
                host:setAlwaysOnTop(true)
            end
        end)
        configureClientPresentationDrawHost(host)
        HTT._clientPresentationDrawHostWarned = false
        return host
    end

    if not ISUIElement then
        if not HTT._clientPresentationDrawHostWarned then
            HTT._clientPresentationDrawHostWarned = true
            HTT.log("Client presentation draw host unavailable: ISUIElement missing")
        end
        return nil
    end

    local ok, created = pcall(function()
        -- Keep bounds tiny so this element never participates in hit-tests.
        local ui = ISUIElement:new(0, 0, 1, 1)
        ui:initialise()
        if ui.addToUIManager then
            ui:addToUIManager()
        end
        pcall(function()
            ui:setX(0)
            ui:setY(0)
            ui:setWidth(1)
            ui:setHeight(1)
        end)
        if ui.setAlwaysOnTop then
            ui:setAlwaysOnTop(true)
        end
        if ui.setVisible then
            ui:setVisible(true)
        end
        configureClientPresentationDrawHost(ui)
        return ui
    end)
    if ok and created then
        HTT._clientPresentationDrawHost = created
        HTT._clientPresentationDrawHostWarned = false
        return created
    end

    if not HTT._clientPresentationDrawHostWarned then
        HTT._clientPresentationDrawHostWarned = true
        HTT.log("Client presentation draw host could not be created")
    end
    return nil
end

local function drawRectSafe(x, y, w, h, a, r, g, b)
    local width = math.floor(HTT.toNumber(w, 0))
    local height = math.floor(HTT.toNumber(h, 0))
    if width <= 0 or height <= 0 then
        return
    end

    local alpha = clamp01(a)
    if alpha <= 0 then
        return
    end

    local rr = clamp01(r or 1)
    local gg = clamp01(g or 1)
    local bb = clamp01(b or 1)
    local host = getClientPresentationDrawHost()
    if not host then
        return
    end

    pcall(function()
        host:drawRectStatic(x, y, width, height, alpha, rr, gg, bb)
    end)
end

local function drawTextCenterSafe(text, x, y, r, g, b, a)
    text = tostring(text or "")
    if text == "" then
        return
    end

    local tm = getTextManager and getTextManager() or nil
    if not tm then
        return
    end

    local rr = clamp01(r or 1)
    local gg = clamp01(g or 1)
    local bb = clamp01(b or 1)
    local aa = clamp01(a or 1)
    local font = UIFont and UIFont.Small or nil
    if not font then
        return
    end

    if tm.DrawStringCentre then
        pcall(function()
            tm:DrawStringCentre(font, x, y, text, rr, gg, bb, aa)
        end)
    elseif tm.DrawString then
        pcall(function()
            tm:DrawString(font, x, y, text, rr, gg, bb, aa)
        end)
    end
end

local function pushDirectionalIndicator(args)
    if HTT.Config.EnableDirectionalSoundIndicator == false then
        return
    end
    if args.indicator ~= true then
        return
    end

    local x = HTT.toNumber(args.indicatorX, HTT.toNumber(args.x, nil))
    local y = HTT.toNumber(args.indicatorY, HTT.toNumber(args.y, nil))
    local z = HTT.toNumber(args.indicatorZ, HTT.toNumber(args.z, 0))
    if x == nil or y == nil then
        return
    end

    local durationSec = HTT.toNumber(
        args.indicatorDuration,
        HTT.toNumber(HTT.Config.BombardmentIndicatorDurationSeconds, 5.0)
    )
    if durationSec <= 0 then
        return
    end

    local durationMs = math.max(1, math.floor(durationSec * 1000))
    local nowMs = getTimestampMsSafe()
    local indicator = {
        x = x,
        y = y,
        z = z,
        text = tostring(args.indicatorText or "BOOM"),
        r = clamp01(HTT.toNumber(args.indicatorR, 1.0)),
        g = clamp01(HTT.toNumber(args.indicatorG, 0.35)),
        b = clamp01(HTT.toNumber(args.indicatorB, 0.12)),
        a = 1.0,
        durationMs = durationMs,
        expireMs = nowMs + durationMs,
    }

    HTT._directionalIndicators[#HTT._directionalIndicators + 1] = indicator
    if #HTT._directionalIndicators > 24 then
        table.remove(HTT._directionalIndicators, 1)
    end
end

local function renderDirectionalIndicators()
    if HTT.Config.EnableDirectionalSoundIndicator == false then
        return
    end

    local indicators = HTT._directionalIndicators
    if not indicators or #indicators <= 0 then
        return
    end

    local core = getCore and getCore() or nil
    if not core then
        return
    end

    local screenW = core:getScreenWidth()
    local screenH = core:getScreenHeight()
    if screenW <= 0 or screenH <= 0 then
        return
    end

    local centerX = math.floor(screenW * 0.5)
    local centerY = math.floor(screenH * 0.5)
    local playerScreenX, playerScreenY = getPlayerScreenPosition(screenW, screenH)
    local ringRadius = math.floor(math.min(screenW, screenH) * 0.36)
    if ringRadius < 72 then
        ringRadius = 72
    end

    local nowMs = getTimestampMsSafe()
    local kept = {}

    local player = getPlayer and getPlayer() or nil
    for i = 1, #indicators do
        local ind = indicators[i]
        local remaining = HTT.toNumber(ind.expireMs, 0) - nowMs
        if remaining > 0 then
            local sourceScreenX, sourceScreenY = worldToScreen(ind.x, ind.y, ind.z)
            local dx = 0
            local dy = 0

            if sourceScreenX ~= nil and sourceScreenY ~= nil then
                dx = sourceScreenX - playerScreenX
                dy = sourceScreenY - playerScreenY
            elseif player then
                dx = ind.x - player:getX()
                dy = ind.y - player:getY()
            end

            local lenSq = dx * dx + dy * dy
            if lenSq > 0.0001 then
                local len = math.sqrt(lenSq)
                local ux = dx / len
                local uy = dy / len

                local ix = math.floor(centerX + ux * ringRadius)
                local iy = math.floor(centerY + uy * ringRadius)

                local durationMs = math.max(HTT.toNumber(ind.durationMs, 1), 1)
                local lifeMul = clamp01(remaining / durationMs)
                local alpha = clamp01(HTT.toNumber(ind.a, 1.0) * lifeMul)

                drawRectSafe(ix - 8, iy - 8, 16, 16, 0.22 * alpha, ind.r, ind.g, ind.b)
                drawRectSafe(ix - 3, iy - 3, 6, 6, 0.95 * alpha, 1, 1, 1)
                drawTextCenterSafe(ind.text, ix, iy + 11, ind.r, ind.g, ind.b, alpha)
            end

            kept[#kept + 1] = ind
        end
    end

    HTT._directionalIndicators = kept
end

local function isSurveillanceScanSound(args)
    args = args or {}
    local soundName = tostring(args.sound or "")
    if soundName == "" then
        return false
    end

    local def = HTT.getEventDefinition and HTT.getEventDefinition("surveillance_event") or nil
    local expected = tostring(def and def.actionSound or "HTT_sensor_scan")
    if expected == "" then
        expected = "HTT_sensor_scan"
    end
    if soundName ~= expected then
        return false
    end

    local eventIdArg = tostring(args.eventId or "")
    if eventIdArg == "surveillance_event" then
        return true
    end

    local state = HTT.serverEvent or {}
    if tostring(state.eventId or "") ~= "surveillance_event" or state.active ~= true then
        return false
    end

    local now = getWorldAgeHoursSafe()
    local startHour = HTT.toNumber(state.startHour, now)
    local endHour = HTT.toNumber(state.endHour, now + 0.0001)
    return now >= (startHour - 0.0001) and now <= (endHour + 0.0001)
end

local function triggerSurveillanceScanOverlay()
    if HTT._clientPresentationEnsureHook then
        HTT._clientPresentationEnsureHook()
    end

    local now = getWorldAgeHoursSafe()
    local cooldownHour = HTT.secondsToWorldHours and HTT.secondsToWorldHours(
        SURVEILLANCE_SCAN_TRIGGER_COOLDOWN_SECONDS,
        SURVEILLANCE_SCAN_TRIGGER_COOLDOWN_SECONDS
    ) or (SURVEILLANCE_SCAN_TRIGGER_COOLDOWN_SECONDS / 3600.0)
    local previous = HTT.toNumber(HTT._surveillanceScanLastTriggerHour, nil)
    if previous ~= nil and (now - previous) < cooldownHour then
        return
    end
    HTT._surveillanceScanLastTriggerHour = now

    local pulseOnHour = HTT.secondsToWorldHours and HTT.secondsToWorldHours(
        SURVEILLANCE_SCAN_PULSE_ON_SECONDS,
        SURVEILLANCE_SCAN_PULSE_ON_SECONDS
    ) or (SURVEILLANCE_SCAN_PULSE_ON_SECONDS / 3600.0)
    local pulseOffHour = HTT.secondsToWorldHours and HTT.secondsToWorldHours(
        SURVEILLANCE_SCAN_PULSE_OFF_SECONDS,
        SURVEILLANCE_SCAN_PULSE_OFF_SECONDS
    ) or (SURVEILLANCE_SCAN_PULSE_OFF_SECONDS / 3600.0)

    HTT._surveillanceScanOverlay = {
        startHour = now,
        pulseCount = SURVEILLANCE_SCAN_PULSE_COUNT,
        pulseOnHour = pulseOnHour,
        pulseOffHour = pulseOffHour,
    }
    HTT.log("Surveillance scan overlay triggered")
end
HTT.TriggerSurveillanceScanOverlay = triggerSurveillanceScanOverlay

local function tickSurveillanceScanOverlayFromEventState()
    local state = HTT.serverEvent or {}
    local scanState = HTT._surveillanceScanState or {}
    HTT._surveillanceScanState = scanState
    local localRelevant = HTT.IsLocalPlayerRelevantToEventState
        and HTT.IsLocalPlayerRelevantToEventState(state)
        or false

    local now = getWorldAgeHoursSafe()
    local eventId = tostring(state.eventId or "")
    local startHour = HTT.toNumber(state.startHour, now)
    local endHour = HTT.toNumber(state.endHour, now)
    local inWindow = now >= (startHour - 0.0001) and now <= (endHour + 0.0001)
    if eventId ~= "surveillance_event" or state.active ~= true or not inWindow or not localRelevant then
        scanState.eventStartHour = nil
        scanState.nextPulseHour = 0
        scanState.triggeredForStart = false
        return
    end

    local previousStart = HTT.toNumber(scanState.eventStartHour, nil)

    if previousStart == nil or math.abs(previousStart - startHour) > 0.000001 then
        local delayHour = HTT.secondsToWorldHours and HTT.secondsToWorldHours(
            SURVEILLANCE_SCAN_ACTION_DELAY_SECONDS,
            SURVEILLANCE_SCAN_ACTION_DELAY_SECONDS
        ) or (SURVEILLANCE_SCAN_ACTION_DELAY_SECONDS / 3600.0)
        scanState.eventStartHour = startHour
        scanState.nextPulseHour = startHour + delayHour
        scanState.triggeredForStart = false
    end

    if scanState.triggeredForStart == true then
        return
    end

    local nextPulseHour = HTT.toNumber(scanState.nextPulseHour, 0)
    if now + 0.000001 < nextPulseHour then
        return
    end

    triggerSurveillanceScanOverlay()
    scanState.triggeredForStart = true
    scanState.nextPulseHour = endHour + 1
end

local function renderSurveillanceScanOverlay()
    local fx = HTT._surveillanceScanOverlay
    if not fx then
        return
    end

    local pulseCount = math.max(1, math.floor(HTT.toNumber(fx.pulseCount, SURVEILLANCE_SCAN_PULSE_COUNT)))
    local pulseOnHour = math.max(0.000001, HTT.toNumber(fx.pulseOnHour, SURVEILLANCE_SCAN_PULSE_ON_SECONDS / 3600.0))
    local pulseOffHour = math.max(0, HTT.toNumber(fx.pulseOffHour, SURVEILLANCE_SCAN_PULSE_OFF_SECONDS / 3600.0))
    local cycleHour = pulseOnHour + pulseOffHour
    if cycleHour <= 0 then
        HTT._surveillanceScanOverlay = nil
        return
    end

    local now = getWorldAgeHoursSafe()
    local elapsed = now - HTT.toNumber(fx.startHour, now)
    if elapsed < 0 then
        elapsed = 0
    end

    local totalDuration = cycleHour * pulseCount
    if elapsed >= totalDuration then
        HTT._surveillanceScanOverlay = nil
        return
    end

    local cycleProgress = elapsed % cycleHour
    if cycleProgress > pulseOnHour then
        return
    end

    local fadeIn = pulseOnHour * 0.30
    local fadeOut = pulseOnHour * 0.40
    local alphaMul = 1.0
    if fadeIn > 0 and cycleProgress < fadeIn then
        alphaMul = cycleProgress / fadeIn
    elseif fadeOut > 0 and cycleProgress > (pulseOnHour - fadeOut) then
        alphaMul = (pulseOnHour - cycleProgress) / fadeOut
    end
    alphaMul = clamp01(alphaMul)
    if alphaMul <= 0 then
        return
    end

    local core = getCore and getCore() or nil
    if not core then
        return
    end

    local screenW = HTT.toNumber(core:getScreenWidth(), 0)
    local screenH = HTT.toNumber(core:getScreenHeight(), 0)
    if screenW <= 0 or screenH <= 0 then
        return
    end

    local scanProgress = pulseOnHour > 0 and clamp01(cycleProgress / pulseOnHour) or 0

    local overlayR = 0.82
    local overlayG = 0.16
    local overlayB = 0.16
    drawRectSafe(0, 0, screenW, screenH, SURVEILLANCE_SCAN_OVERLAY_ALPHA * alphaMul, overlayR, overlayG, overlayB)

    local barH = math.max(16, math.floor(screenH * 0.18))
    local scanY = math.floor((screenH + barH) * scanProgress) - barH
    drawRectSafe(0, scanY, screenW, barH, SURVEILLANCE_SCAN_BAR_ALPHA * alphaMul, 0.95, 0.22, 0.22)
end

local function renderClientPresentation()
    if SURVEILLANCE_SCAN_TRIGGER_FROM_EVENT_STATE then
        tickSurveillanceScanOverlayFromEventState()
    end
    renderDirectionalIndicators()
    renderSurveillanceScanOverlay()
end

local function ensureClientPresentationDrawHook()
    if HTT._clientPresentationDrawHooked == true then
        return true
    end

    if registerEvent("OnPostUIDraw", renderClientPresentation) then
        HTT._clientPresentationDrawHooked = true
        HTT._clientPresentationDrawHook = "OnPostUIDraw"
        return true
    end

    if registerEvent("OnPreUIDraw", renderClientPresentation) then
        HTT._clientPresentationDrawHooked = true
        HTT._clientPresentationDrawHook = "OnPreUIDraw"
        return true
    end

    return false
end
HTT._clientPresentationEnsureHook = ensureClientPresentationDrawHook

local isSinglePlayerLocalSession

local function playLocalSound(soundId, x, y, z, opts)
    if not soundId or soundId == "" then
        return false
    end

    local function clamp01(value)
        local n = HTT.toNumber(value, 1)
        if n < 0 then
            return 0
        end
        if n > 1 then
            return 1
        end
        return n
    end

    local function clampVolumeMul(value)
        local n = HTT.toNumber(value, 1)
        if n < 0 then
            return 0
        end
        if n > 2 then
            return 2
        end
        return n
    end

    local function clampPitch(value)
        local n = HTT.toNumber(value, 1.0)
        if n < 0.5 then
            return 0.5
        end
        if n > 1.5 then
            return 1.5
        end
        return n
    end

    local function getEventSoundVolumeMultiplier()
        local percent = HTT.toNumber(HTT.Config.EventSoundVolumePercent, 100)
        if HTT.GetClientEventSoundVolumePercent then
            percent = HTT.toNumber(HTT.GetClientEventSoundVolumePercent(), percent)
        end
        if percent < 0 then
            percent = 0
        end
        if percent > 100 then
            percent = 100
        end
        return clamp01(percent / 100)
    end

    local function isValidHandle(handle)
        return handle ~= nil and handle ~= 0 and handle ~= false
    end

    local function isNumericHandle(handle)
        return type(handle) == "number"
    end

    local function callAudioObjectMethod(handle, methodName, arg)
        if not isValidHandle(handle) then
            return false
        end
        if methodName == nil or methodName == "" then
            return false
        end

        local method = nil
        local okLookup = pcall(function()
            method = handle[methodName]
        end)
        if not okLookup or type(method) ~= "function" then
            return false
        end

        local okCall = pcall(function()
            method(handle, arg)
        end)
        return okCall == true
    end

    local function trySetVolumeOnAudioObject(handle, volume)
        if not isValidHandle(handle) then
            return false
        end

        if callAudioObjectMethod(handle, "setVolume", volume) then
            return true
        end

        if callAudioObjectMethod(handle, "setVolumeAll", volume) then
            return true
        end

        return false
    end

    local function applyVolumeToHandle(emitter, handle, volume)
        if math.abs(HTT.toNumber(volume, 1.0) - 1.0) <= 0.001 then
            return
        end
        if not isValidHandle(handle) then
            return
        end

        -- B42 may return FMODAudio objects (userdata) instead of numeric handles.
        if trySetVolumeOnAudioObject(handle, volume) then
            return
        end

        if not isNumericHandle(handle) then
            return
        end
        if not emitter or not emitter.setVolume then
            return
        end

        pcall(function()
            emitter:setVolume(handle, volume)
        end)
    end

    local function trySetPitchOnAudioObject(handle, pitch)
        if not isValidHandle(handle) then
            return false
        end

        return callAudioObjectMethod(handle, "setPitch", pitch)
    end

    local function applyPitchToHandle(emitter, handle, pitch)
        if math.abs(HTT.toNumber(pitch, 1.0) - 1.0) <= 0.001 then
            return
        end
        if not isValidHandle(handle) then
            return
        end

        -- B42 may return FMODAudio objects (userdata) instead of numeric handles.
        if trySetPitchOnAudioObject(handle, pitch) then
            return
        end

        if not isNumericHandle(handle) then
            return
        end
        if not emitter then
            return
        end

        if emitter.setPitch then
            pcall(function()
                emitter:setPitch(handle, pitch)
            end)
            return
        end

        if emitter.setParameterValue then
            pcall(function()
                emitter:setParameterValue(handle, "Pitch", pitch)
            end)
        end
    end

    local function getSoundManagerSafe()
        if not getSoundManager then
            return nil
        end
        local ok, soundManager = pcall(getSoundManager)
        if ok then
            return soundManager
        end
        return nil
    end

    local function tryPlaySoundOnEmitter(emitter, volume, pitch)
        if not emitter then
            return false
        end

        local handle = nil
        local ok = false
        if emitter.playSound then
            ok, handle = pcall(function()
                return emitter:playSound(soundId)
            end)
        end
        if (not ok or not isValidHandle(handle)) and emitter.playSoundImpl then
            ok, handle = pcall(function()
                return emitter:playSoundImpl(soundId, nil)
            end)
        end
        if not ok or not isValidHandle(handle) then
            return false
        end

        applyVolumeToHandle(emitter, handle, volume)
        applyPitchToHandle(emitter, handle, pitch)
        return true
    end

    local function tryPlay2DSound(soundManager, volume, pitch)
        if not soundManager or not soundManager.PlaySound then
            return false
        end

        local ok, handle = pcall(function()
            return soundManager:PlaySound(soundId, false, 1.0)
        end)
        if not ok or not isValidHandle(handle) then
            return false
        end

        applyVolumeToHandle(nil, handle, volume)
        applyPitchToHandle(nil, handle, pitch)
        return true
    end

    local function tryPlayWorldSoundOnSquare(soundManager, sourceSquare, volume)
        if not soundManager or not sourceSquare or not soundManager.PlayWorldSound then
            return false
        end

        local ok = pcall(function()
            soundManager:PlayWorldSound(soundId, sourceSquare, 0, 40, volume, false)
        end)
        return ok == true
    end

    local function tryPlayWorldSoundImpl(soundManager, sx, sy, sz, volume)
        if not soundManager or not soundManager.PlayWorldSoundImpl then
            return false
        end

        local ok = pcall(
            soundManager.PlayWorldSoundImpl,
            soundManager,
            soundId,
            false,
            sx,
            sy,
            sz,
            0,
            40,
            volume,
            false
        )
        return ok == true
    end

    local function tryPlaySquareSound(sourceSquare)
        if not sourceSquare or not sourceSquare.playSound then
            return false
        end

        local ok = pcall(function()
            sourceSquare:playSound(soundId)
        end)
        return ok == true
    end

    local function tryPlayPlayerLocalSound(playerObj, volume, pitch)
        if not playerObj or not playerObj.playSoundLocal then
            return false
        end

        local ok, handle = pcall(function()
            return playerObj:playSoundLocal(soundId)
        end)
        if not ok or not isValidHandle(handle) then
            return false
        end

        applyVolumeToHandle(nil, handle, volume)
        applyPitchToHandle(nil, handle, pitch)
        return true
    end

    local function tryPlayOnPlayer(playerObj, volume, pitch, preferLocal, soundManager, allowDirectPlayerFallback)
        if not playerObj then
            return false, nil
        end
        if allowDirectPlayerFallback == nil then
            allowDirectPlayerFallback = true
        end

        if preferLocal then
            if tryPlayPlayerLocalSound(playerObj, volume, pitch) then
                return true, "player-local"
            end
            if tryPlay2DSound(soundManager, volume, pitch) then
                return true, "sound-2d"
            end
        end

        if playerObj.getEmitter then
            local attachedEmitter = nil
            pcall(function()
                attachedEmitter = playerObj:getEmitter()
            end)
            if tryPlaySoundOnEmitter(attachedEmitter, volume, pitch) then
                return true, "player-emitter"
            end
        end

        if allowDirectPlayerFallback ~= true then
            return false, nil
        end

        if not playerObj.playSound then
            return false, nil
        end

        local ok, handle = pcall(function()
            return playerObj:playSound(soundId)
        end)
        if ok == true and isValidHandle(handle) then
            applyVolumeToHandle(nil, handle, volume)
            applyPitchToHandle(nil, handle, pitch)
            return true, "player"
        end
        if ok == true then
            return true, "player"
        end
        return false, nil
    end

    opts = opts or {}
    local sourceVolumeMul = clampVolumeMul(opts.volumeMul)
    local sourcePitch = clampPitch(opts.pitch)
    local attachToPlayerEmitter = opts.attachToPlayerEmitter == true
    local preferLocalPlayerSound = opts.preferLocalPlayerSound == true
    local localOnly = opts.localOnly == true
    local noSquareSound = opts.noSquareSound == true
    local noWorldSound = opts.noWorldSound == true
    local delayDirectPlayerFallback = false

    if isSinglePlayerLocalSession()
        and attachToPlayerEmitter
        and preferLocalPlayerSound
        and not localOnly
    then
        delayDirectPlayerFallback = true
    end

    local player = getPlayer()
    if not player then
        return false
    end

    local playerSquare = player:getSquare()
    local square = playerSquare
    if x ~= nil and y ~= nil and getCell then
        local gx = math.floor(HTT.toNumber(x, player:getX()))
        local gy = math.floor(HTT.toNumber(y, player:getY()))
        local gz = math.floor(HTT.toNumber(z, player:getZ()))
        local sourceSquare = getCell():getGridSquare(gx, gy, gz)
        if sourceSquare then
            square = sourceSquare
        end
    end
    local played = false
    local playedRoute = nil
    local volumeMul = getEventSoundVolumeMultiplier() * sourceVolumeMul
    if volumeMul < 0 then
        volumeMul = 0
    elseif volumeMul > 2 then
        volumeMul = 2
    end
    if volumeMul <= 0 then
        HTT.log("Client sound muted by sandbox volume: " .. tostring(soundId))
        return true
    end

    local world = getWorld and getWorld() or nil
    local soundManager = getSoundManagerSafe()

    if attachToPlayerEmitter then
        local playedOnPlayer, playerRoute = tryPlayOnPlayer(
            player,
            volumeMul,
            sourcePitch,
            preferLocalPlayerSound or localOnly,
            soundManager,
            not delayDirectPlayerFallback
        )
        if playedOnPlayer then
            played = true
            playedRoute = playerRoute
        end
    end

    if not played and attachToPlayerEmitter and not noSquareSound then
        local attachedSquare = playerSquare or square
        if tryPlaySquareSound(attachedSquare) then
            played = true
            playedRoute = attachedSquare == playerSquare and "player-square" or "square"
        end
    end

    if not played and not localOnly and not noWorldSound and tryPlayWorldSoundOnSquare(soundManager, square, volumeMul) then
        played = true
        playedRoute = "world-square"
    end

    if not played and not localOnly and not noWorldSound and world and world.getFreeEmitter then
        local emitter = world:getFreeEmitter()
        if emitter then
            local sx = square and square.getX and square:getX() or player:getX()
            local sy = square and square.getY and square:getY() or player:getY()
            local sz = square and square.getZ and square:getZ() or player:getZ()
            if emitter.setPos then
                pcall(function()
                    emitter:setPos(sx, sy, sz)
                end)
            end
            if tryPlaySoundOnEmitter(emitter, volumeMul, sourcePitch) then
                played = true
                playedRoute = "world-emitter"
            end
        end
    end

    if not played and not noSquareSound and tryPlaySquareSound(square) then
        played = true
        playedRoute = square == playerSquare and "player-square" or "square"
    end

    if not played and not localOnly and not noWorldSound then
        local fx = square and square.getX and square:getX() or player:getX()
        local fy = square and square.getY and square:getY() or player:getY()
        local fz = square and square.getZ and square:getZ() or player:getZ()
        if tryPlayWorldSoundImpl(soundManager, fx, fy, fz, volumeMul) then
            played = true
            playedRoute = "world-impl"
        end
    end

    if not played and tryPlay2DSound(soundManager, volumeMul, sourcePitch) then
        played = true
        playedRoute = "sound-2d"
    end

    if not played then
        local playedOnPlayer, playerRoute = tryPlayOnPlayer(
            player,
            volumeMul,
            sourcePitch,
            true,
            soundManager,
            true
        )
        if playedOnPlayer then
            played = true
            playedRoute = playerRoute
        end
    end

    if not played and playerSquare and square ~= playerSquare and not noSquareSound and tryPlaySquareSound(playerSquare) then
        played = true
        playedRoute = "player-square"
    end

    logClientSoundState(soundId, played, playedRoute)

    return played
end

local function isEventPhaseSound(eventId, soundName)
    local def = HTT.getEventDefinition and HTT.getEventDefinition(eventId) or nil
    if not def then
        return false
    end

    soundName = tostring(soundName or "")
    return soundName == tostring(def.startSound or "")
        or soundName == tostring(def.approachSound or "")
        or soundName == tostring(def.activeSound or "")
        or soundName == tostring(def.loopSound or "")
        or soundName == tostring(def.collapseSound or "")
        or soundName == tostring(def.impactSound or "")
        or soundName == tostring(def.passSound or "")
        or soundName == tostring(def.explosionSound or "")
        or soundName == tostring(def.voiceSound or "")
        or soundName == tostring(def.endSound or "")
        or soundName == tostring(def.fireSound or "")
        or soundName == tostring(def.hitSound or "")
end

local function isEventPresenceSound(eventId, soundName)
    local def = HTT.getEventDefinition and HTT.getEventDefinition(eventId) or nil
    if not def then
        return false
    end

    soundName = tostring(soundName or "")
    return soundName == tostring(def.startSound or "")
        or soundName == tostring(def.approachSound or "")
        or soundName == tostring(def.activeSound or "")
        or soundName == tostring(def.loopSound or "")
end

local function shouldAttachCurrentEventPresenceSoundToPlayer(soundName)
    local state = HTT.serverEvent
    if type(state) ~= "table" then
        return false
    end

    local eventId = tostring(state.eventId or "")
    if eventId == "" then
        return false
    end

    if not isEventPresenceSound(eventId, soundName) then
        return false
    end

    if HTT.IsLocalPlayerRelevantToEventState then
        return HTT.IsLocalPlayerRelevantToEventState(state, 80)
    end

    return true
end

isSinglePlayerLocalSession = function()
    local inClient = isClient and isClient() or false
    local inServer = isServer and isServer() or false
    local isDedicatedServer = inServer and not inClient
    if isDedicatedServer then
        return false
    end

    if getPlayer then
        local p = getPlayer()
        if p then
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

    return not inClient and not inServer
end

local function isEventPlayerAttachedSound(eventId, soundName)
    local def = HTT.getEventDefinition and HTT.getEventDefinition(eventId) or nil
    if not def then
        return false
    end

    soundName = tostring(soundName or "")
    return soundName == tostring(def.startSound or "")
        or soundName == tostring(def.approachSound or "")
        or soundName == tostring(def.activeSound or "")
        or soundName == tostring(def.loopSound or "")
        or soundName == tostring(def.collapseSound or "")
        or soundName == tostring(def.passSound or "")
        or soundName == tostring(def.impactSound or "")
        or soundName == tostring(def.explosionSound or "")
        or soundName == tostring(def.actionSound or "")
        or soundName == tostring(def.voiceSound or "")
        or soundName == tostring(def.fireSound or "")
        or soundName == tostring(def.endSound or "")
end

local function shouldAttachCommandEventSoundToPlayer(args, soundName, sx, sy, sz, radius)
    args = args or {}

    local eventId = tostring(args.eventId or "")
    if eventId == "" then
        return false
    end

    if not isEventPlayerAttachedSound(eventId, soundName) then
        return false
    end

    local state = HTT.serverEvent
    if type(state) == "table" and tostring(state.eventId or "") == eventId then
        if HTT.IsLocalPlayerRelevantToEventState then
            return HTT.IsLocalPlayerRelevantToEventState(state, 80)
        end
        return true
    end

    if HTT.IsLocalPlayerRelevantToEventState then
        return HTT.IsLocalPlayerRelevantToEventState({
            centerX = HTT.toNumber(sx, 0),
            centerY = HTT.toNumber(sy, 0),
            centerZ = HTT.toNumber(sz, 0),
            radius = HTT.toNumber(radius, HTT.Config.DefaultSoundRadius),
            followOnlineId = HTT.toNumber(args.followOnlineId, nil),
        }, 80)
    end

    return isSinglePlayerLocalSession()
end

function HTT.StartToxicEvent(eventData)
    if HTT.active then
        return
    end

    HTT.active = true
    HTT.heliActive = true
    HTT.serverEvent = eventData or HTT.serverEvent

    HTT.log("Client toxic event STARTED")
end

function HTT.EndToxicEvent(reason)
    if not HTT.active then
        return
    end

    HTT.active = false
    HTT.heliActive = false

    HTT.log("Client toxic event ENDED reason=" .. tostring(reason or "unknown"))
end

function HTT.ClientPlaySoundNearPlayer(args)
    args = args or {}

    local soundName = tostring(args.sound or "")
    if soundName == "" then
        return
    end

    local sid = HTT.toNumber(args.sid, nil)
    local internalReplay = args._internalReplay == true

    if not internalReplay and HTT.isTimeFastForward and HTT.isTimeFastForward() then
        queuePendingSoundCommand(args)
        return
    end

    if not markSoundSidSeen(sid) then
        return
    end

    pushDirectionalIndicator(args)

    local player = getPlayer()
    if not player then
        return
    end

    local px = player:getX()
    local py = player:getY()
    local sx = HTT.toNumber(args.x, px)
    local sy = HTT.toNumber(args.y, py)
    local sz = HTT.toNumber(args.z, player:getZ())
    local radius = HTT.toNumber(args.radius, HTT.Config.DefaultSoundRadius)

    local attachToPlayerEmitter = args.attachToLocalPlayer == true
    local attachedToFollowPlayer = false
    if not attachToPlayerEmitter and args.attachToFollowPlayer == true then
        local followOnlineId = HTT.toNumber(args.followOnlineId, nil)
        if followOnlineId == nil or isSinglePlayerLocalSession() then
            attachToPlayerEmitter = true
            attachedToFollowPlayer = true
        elseif HTT.IsLocalPlayerFollowTarget and HTT.IsLocalPlayerFollowTarget(followOnlineId) then
            attachToPlayerEmitter = true
            attachedToFollowPlayer = true
        elseif player.getOnlineID then
            local localOnlineId = HTT.toNumber(player:getOnlineID(), nil)
            if localOnlineId ~= nil and localOnlineId == followOnlineId then
                attachToPlayerEmitter = true
                attachedToFollowPlayer = true
            end
        end
    end
    local attachedToCommandEvent = false
    if not attachToPlayerEmitter and shouldAttachCommandEventSoundToPlayer(args, soundName, sx, sy, sz, radius) then
        attachToPlayerEmitter = true
        attachedToCommandEvent = true
    end
    local attachedToCurrentEvent = false
    if not attachToPlayerEmitter and shouldAttachCurrentEventPresenceSoundToPlayer(soundName) then
        attachToPlayerEmitter = true
        attachedToCurrentEvent = true
    end

    local preferLocalPlayerSound = args.preferLocalPlayerSound == true
    local localOnly = args.localOnly == true
    if isSinglePlayerLocalSession()
        and attachToPlayerEmitter
        and not preferLocalPlayerSound
        and (attachedToFollowPlayer or attachedToCommandEvent or attachedToCurrentEvent)
    then
        preferLocalPlayerSound = true
    end

    if attachToPlayerEmitter then
        sx = px
        sy = py
        sz = player:getZ()
    end

    local dx = px - sx
    local dy = py - sy

    local bypassRangeCheck = false
    if attachToPlayerEmitter then
        bypassRangeCheck = true
    end

    if not bypassRangeCheck and radius > 0 and (dx * dx + dy * dy) > (radius * radius) then
        return
    end

    if isSurveillanceScanSound(args) then
        triggerSurveillanceScanOverlay()
    end

    local playbackSoundName = HTT.getResolvedRotorSoundId and HTT.getResolvedRotorSoundId(soundName) or soundName

    playLocalSound(playbackSoundName, sx, sy, sz, {
        localOnly = localOnly,
        noSquareSound = args.noSquareSound == true,
        noWorldSound = args.noWorldSound == true,
        preferLocalPlayerSound = preferLocalPlayerSound,
        volumeMul = HTT.toNumber(args.volumeMul, 1.0),
        pitch = HTT.toNumber(args.pitch, 1.0),
        attachToPlayerEmitter = attachToPlayerEmitter,
    })
end

ensureClientPresentationDrawHook()

registerEvent("OnTick", flushPendingSoundCommands)

registerEvent("OnGameStart", function()
    local hooked = ensureClientPresentationDrawHook()
    if hooked then
        HTT.log("Directional sound indicator loaded")
    else
        HTT.log("Directional sound indicator could not hook draw event")
    end
    HTT.log("Client presentation draw hook=" .. tostring(HTT._clientPresentationDrawHook))
    HTT.log("Client toxic presentation loaded")
end)
