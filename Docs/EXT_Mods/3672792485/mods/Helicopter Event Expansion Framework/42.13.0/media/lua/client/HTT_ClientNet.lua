require "HTT_Main"
require "HTT_ToxicEvent"
require "ISUI/ISUIElement"

HTT = HTT or {}

local EMI_CLOCK_SCRIPT_SIGNATURE = "2026-03-19-clock-mask-v13-local-host-bounds"

if HTT._clientNetLoaded then
    if HTT and HTT.log then
        HTT.log(
            "Client network chunk skipped (already loaded, signature=" .. EMI_CLOCK_SCRIPT_SIGNATURE .. ")"
        )
    end
    return
end
HTT._clientNetLoaded = true
HTT._emiClockInterferenceActive = HTT._emiClockInterferenceActive == true
HTT._emiClockRestorePending = HTT._emiClockRestorePending == true
HTT._emiClockHandle = HTT._emiClockHandle or nil
HTT._emiClockPulsePhaseActive = HTT._emiClockPulsePhaseActive == true
HTT._emiClockMaskDrawHost = HTT._emiClockMaskDrawHost or nil
HTT._emiClockAssetCache = HTT._emiClockAssetCache or {}
HTT._emiClockMaskWarnedNoHost = HTT._emiClockMaskWarnedNoHost == true
HTT._emiClockMaskWarnedNoAssets = HTT._emiClockMaskWarnedNoAssets == true

local EMI_CLOCK_STATE_KEY = "HTT_PreEMI_ClockState"
local EMI_CLOCK_SNAPSHOT_VALID_KEY = "HTT_PreEMI_ClockSnapshotValid"
local EMI_CLOCK_STATE_LEGACY_KEY = "HTT_PreEMI_ClockVisible"
local EMI_CLOCK_MODIFIED_KEY = "HTT_PreEMI_ClockModified"
local EMI_CLOCK_REMOVED_KEY = "HTT_PreEMI_ClockRemovedFromUI"

local EMI_CLOCK_MASK_BG_ALPHA = 1.00
local EMI_CLOCK_MASK_TEXT_ALPHA = 0.98
local EMI_CLOCK_MASK_BG_R = 0.02
local EMI_CLOCK_MASK_BG_G = 0.06
local EMI_CLOCK_MASK_BG_B = 0.08
local EMI_CLOCK_MASK_TEXT_R = 0.47
local EMI_CLOCK_MASK_TEXT_G = 0.92
local EMI_CLOCK_MASK_TEXT_B = 0.98
local EMI_CLOCK_MASK_SUBTEXT_R = 0.38
local EMI_CLOCK_MASK_SUBTEXT_G = 0.74
local EMI_CLOCK_MASK_SUBTEXT_B = 0.80

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

local function getPlayerModDataSafe()
    local player = getPlayer and getPlayer() or nil
    if not player or not player.getModData then
        return nil
    end

    local ok, modData = pcall(function()
        return player:getModData()
    end)
    if not ok then
        return nil
    end
    return modData
end

local function getClockSafe()
    if UIManager and UIManager.getClock then
        local ok, clock = pcall(function()
            return UIManager.getClock()
        end)
        if ok and clock then
            HTT._emiClockHandle = clock
            return clock
        end
    end

    local cachedClock = HTT._emiClockHandle
    if cachedClock then
        local okMethod, method = pcall(function()
            return cachedClock.setVisible
        end)
        if okMethod and type(method) == "function" then
            return cachedClock
        end
    end

    return nil
end

local function getClockVisibleSafe(clock)
    if not clock then
        return nil
    end

    local okMethod, visible = pcall(function()
        return clock:isVisible()
    end)
    if okMethod and visible ~= nil then
        return visible == true
    end

    local okField, fieldVisible = pcall(function()
        return clock.visible
    end)
    if okField and fieldVisible ~= nil then
        return fieldVisible == true
    end

    return nil
end

local function getPlayerDigitalWatchVisibleFallback()
    local player = getPlayer and getPlayer() or nil
    if not player or not player.isWearingDigitalWatch then
        return nil
    end

    local ok, visible = pcall(function()
        return player:isWearingDigitalWatch()
    end)
    if ok and visible ~= nil then
        return visible == true
    end
    return nil
end

local function setClockVisibleSafe(clock, visible)
    if not clock then
        return false
    end

    local show = visible == true
    local applied = false

    local ok = pcall(function()
        if clock.setVisible then
            clock:setVisible(show)
            applied = true
        end
    end)
    if not ok then
        applied = false
    end

    if not applied then
        pcall(function()
            clock.visible = show
            applied = true
        end)
    end

    local visibleNow = getClockVisibleSafe(clock)
    if visibleNow ~= nil then
        return visibleNow == show
    end

    return applied
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

    local rr = clamp01(r)
    local gg = clamp01(g)
    local bb = clamp01(b)

    if ISUIElement and ISUIElement.drawRectStatic then
        local ok = pcall(ISUIElement.drawRectStatic, x, y, width, height, alpha, rr, gg, bb)
        if ok then
            return
        end
    end

    if type(drawRect) == "function" then
        pcall(drawRect, x, y, width, height, alpha, rr, gg, bb)
    end
end

local function drawHostRectSafe(host, x, y, w, h, a, r, g, b)
    if not host then
        drawRectSafe(x, y, w, h, a, r, g, b)
        return
    end

    local width = math.floor(HTT.toNumber(w, 0))
    local height = math.floor(HTT.toNumber(h, 0))
    if width <= 0 or height <= 0 then
        return
    end

    local alpha = clamp01(a)
    if alpha <= 0 then
        return
    end

    local rr = clamp01(r)
    local gg = clamp01(g)
    local bb = clamp01(b)

    local drawn = false
    pcall(function()
        if host.drawRect then
            host:drawRect(
                math.floor(HTT.toNumber(x, 0)),
                math.floor(HTT.toNumber(y, 0)),
                width,
                height,
                alpha,
                rr,
                gg,
                bb
            )
            drawn = true
        end
    end)
    if drawn then
        return
    end

    local absX = math.floor(HTT.toNumber(x, 0))
    local absY = math.floor(HTT.toNumber(y, 0))
    pcall(function()
        if host.getAbsoluteX then
            absX = host:getAbsoluteX() + math.floor(HTT.toNumber(x, 0))
        elseif host.getX then
            absX = host:getX() + math.floor(HTT.toNumber(x, 0))
        end
        if host.getAbsoluteY then
            absY = host:getAbsoluteY() + math.floor(HTT.toNumber(y, 0))
        elseif host.getY then
            absY = host:getY() + math.floor(HTT.toNumber(y, 0))
        end
    end)
    drawRectSafe(absX, absY, width, height, alpha, rr, gg, bb)
end

local function setEMIClockMaskDrawHostBounds(host, x, y, w, h)
    if not host then
        return
    end

    local width = math.max(1, math.floor(HTT.toNumber(w, 1)))
    local height = math.max(1, math.floor(HTT.toNumber(h, 1)))
    local px = math.floor(HTT.toNumber(x, 0))
    local py = math.floor(HTT.toNumber(y, 0))

    pcall(function()
        if host.setX then
            host:setX(px)
        end
        if host.setY then
            host:setY(py)
        end
        if host.setWidth then
            host:setWidth(width)
        end
        if host.setHeight then
            host:setHeight(height)
        end
        if host.setVisible then
            host:setVisible(true)
        end
        if host.setAlwaysOnTop then
            host:setAlwaysOnTop(true)
        end
    end)
end

local function configureEMIClockMaskDrawHost(host)
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

local function destroyEMIClockMaskDrawHost()
    local host = HTT._emiClockMaskDrawHost
    if not host then
        return
    end

    pcall(function()
        if host.setVisible then
            host:setVisible(false)
        end
    end)

    local removed = false
    if host.removeFromUIManager then
        pcall(function()
            host:removeFromUIManager()
            removed = true
        end)
    end

    if not removed and UIManager and UIManager.RemoveElement and host.javaObject then
        pcall(function()
            UIManager.RemoveElement(host.javaObject)
            removed = true
        end)
    end

    if not removed and not host.javaObject and UIManager and UIManager.RemoveElement then
        pcall(function()
            UIManager.RemoveElement(host)
            removed = true
        end)
    end

    HTT._emiClockMaskDrawHost = nil
end

local function getEMIClockMaskDrawHost()
    local host = HTT._emiClockMaskDrawHost
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
        configureEMIClockMaskDrawHost(host)
        return host
    end

    if not ISUIElement then
        return nil
    end

    local ok, created = pcall(function()
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
        configureEMIClockMaskDrawHost(ui)
        return ui
    end)
    if ok and created then
        HTT._emiClockMaskDrawHost = created
        return created
    end
    return nil
end

local function loadClockTexture(path)
    local tex = nil
    local ok = pcall(function()
        tex = getTexture(path)
    end)
    if not ok then
        return nil
    end
    return tex
end

local function getClockMaskConfig(largeClock)
    if largeClock then
        return {
            ux = 3,
            uy = 3,
            largeDigitSpacing = 2,
            smallDigitSpacing = 1,
            colonSpacing = 3,
            decimalSpacing = 2,
            degreeSpacing = 2,
            slashSpacing = 2,
            tempDateSpacing = 8,
            displayVerticalSpacing = 5,
            decimalVerticalSpacing = 15,
        }
    end

    return {
        ux = 3,
        uy = 3,
        largeDigitSpacing = 1,
        smallDigitSpacing = 1,
        colonSpacing = 1,
        decimalSpacing = 1,
        degreeSpacing = 1,
        slashSpacing = 1,
        tempDateSpacing = 5,
        displayVerticalSpacing = 2,
        decimalVerticalSpacing = 6,
    }
end

local function getEMIClockAssets(largeClock)
    local key = largeClock and "large" or "small"
    local cached = HTT._emiClockAssetCache[key]
    if cached then
        return cached
    end

    local largeSuffix = largeClock and "Large" or "Medium"
    local smallSuffix = largeClock and "Medium" or "Small"

    local assets = {
        background = loadClockTexture("media/ui/ClockAssets/Clock" .. (largeClock and "Large" or "Small") .. "Background.png"),
        digitsLarge = {},
        digitsSmall = {},
        colon = loadClockTexture("media/ui/ClockAssets/ClockDivide" .. largeSuffix .. ".png"),
        minusTop = loadClockTexture("media/ui/ClockAssets/ClockDigitsMediumMinus.png"),
        minusBottom = loadClockTexture("media/ui/ClockAssets/ClockDigits" .. smallSuffix .. "Minus.png"),
        dot = loadClockTexture("media/ui/ClockAssets/ClockDigits" .. smallSuffix .. "Dot.png"),
        tempC = loadClockTexture("media/ui/ClockAssets/ClockDigits" .. smallSuffix .. "C.png"),
        tempF = loadClockTexture("media/ui/ClockAssets/ClockDigits" .. smallSuffix .. "F.png"),
        slash = loadClockTexture("media/ui/ClockAssets/DateDivide" .. smallSuffix .. ".png"),
    }

    for i = 0, 9 do
        assets.digitsLarge[i] = loadClockTexture(
            "media/ui/ClockAssets/ClockDigits" .. largeSuffix .. tostring(i) .. ".png"
        )
        assets.digitsSmall[i] = loadClockTexture(
            "media/ui/ClockAssets/ClockDigits" .. smallSuffix .. tostring(i) .. ".png"
        )
    end

    HTT._emiClockAssetCache[key] = assets
    return assets
end

local function drawClockTexture(host, texture, x, y, a, r, g, b)
    if not host or not texture then
        return
    end
    pcall(function()
        if host.drawTextureStatic then
            host:drawTextureStatic(texture, x, y, clamp01(a), clamp01(r), clamp01(g), clamp01(b))
        else
            host:drawTexture(texture, x, y, clamp01(a), clamp01(r), clamp01(g), clamp01(b))
        end
    end)
end

local function drawMinusInDigitCell(host, minusTex, cellX, cellY, cellW, cellH, a, r, g, b)
    if not minusTex then
        return
    end

    local w = minusTex.getWidth and minusTex:getWidth() or 0
    local h = minusTex.getHeight and minusTex:getHeight() or 0
    if w <= 0 or h <= 0 then
        return
    end

    local drawX = cellX + math.floor((cellW - w) * 0.5)
    local drawY = cellY + math.floor((cellH - h) * 0.5)
    drawClockTexture(host, minusTex, drawX, drawY, a, r, g, b)
end

local function removeClockFromUIManagerSafe(clock)
    if not clock or not UIManager or not UIManager.RemoveElement then
        return false
    end

    local removed = false
    pcall(function()
        UIManager.RemoveElement(clock)
        removed = true
    end)

    if not removed then
        pcall(function()
            if clock.javaObject then
                UIManager.RemoveElement(clock.javaObject)
                removed = true
            end
        end)
    end

    return removed
end

local function addClockToUIManagerSafe(clock)
    if not clock then
        return false
    end

    local added = false
    if UIManager and UIManager.AddUI then
        pcall(function()
            if clock.javaObject then
                UIManager.AddUI(clock.javaObject)
            else
                UIManager.AddUI(clock)
            end
            added = true
        end)
    end

    if not added and clock.addToUIManager then
        pcall(function()
            clock:addToUIManager()
            added = true
        end)
    end

    if clock.resize then
        pcall(function()
            clock:resize()
        end)
    end

    return added
end

local function getClockBoundsSafe(clock)
    if not clock then
        return nil, nil, nil, nil
    end

    local x = nil
    local y = nil
    local w = nil
    local h = nil

    pcall(function()
        if clock.getX then
            x = clock:getX()
        else
            x = clock.x
        end
    end)
    pcall(function()
        if clock.getY then
            y = clock:getY()
        else
            y = clock.y
        end
    end)
    pcall(function()
        if clock.getWidth then
            w = clock:getWidth()
        else
            w = clock.width
        end
    end)
    pcall(function()
        if clock.getHeight then
            h = clock:getHeight()
        else
            h = clock.height
        end
    end)

    x = HTT.toNumber(x, nil)
    y = HTT.toNumber(y, nil)
    w = HTT.toNumber(w, nil)
    h = HTT.toNumber(h, nil)
    if x == nil or y == nil or w == nil or h == nil then
        return nil, nil, nil, nil
    end
    if w <= 0 or h <= 0 then
        return nil, nil, nil, nil
    end

    return math.floor(x), math.floor(y), math.floor(w), math.floor(h)
end

local function triggerEMIClockPulseMask()
    if HTT._emiClockPulsePhaseActive ~= true then
        HTT.log("EMI clock mask phase armed (entered on pulse)")
    end
    HTT._emiClockPulsePhaseActive = true
end

local function isEMIClockPulseMaskActive()
    if HTT._emiClockInterferenceActive ~= true then
        return false
    end
    return HTT._emiClockPulsePhaseActive == true
end

local function renderEMIClockMaskOverlay()
    if not isEMIClockPulseMaskActive() then
        destroyEMIClockMaskDrawHost()
        return
    end

    local clock = getClockSafe()
    if not clock then
        destroyEMIClockMaskDrawHost()
        return
    end

    local x, y, w, h = getClockBoundsSafe(clock)
    if not x then
        destroyEMIClockMaskDrawHost()
        return
    end

    local padX = 0
    local padY = 0
    local innerX = x + padX
    local innerY = y + padY
    local innerW = w - (padX * 2)
    local innerH = h - (padY * 2)
    if innerW <= 8 or innerH <= 8 then
        destroyEMIClockMaskDrawHost()
        return
    end

    local core = getCore and getCore() or nil
    local largeClock = false
    if core and core.getOptionClockSize then
        local okClockSize, clockSize = pcall(function()
            return core:getOptionClockSize()
        end)
        if okClockSize then
            largeClock = HTT.toNumber(clockSize, 1) == 2
        end
    end

    local assets = getEMIClockAssets(largeClock)
    local host = getEMIClockMaskDrawHost()
    if not host or not assets then
        destroyEMIClockMaskDrawHost()
        if not host and not HTT._emiClockMaskWarnedNoHost then
            HTT._emiClockMaskWarnedNoHost = true
            HTT.log("EMI clock mask: draw host unavailable")
        end
        if not assets and not HTT._emiClockMaskWarnedNoAssets then
            HTT._emiClockMaskWarnedNoAssets = true
            HTT.log("EMI clock mask: assets unavailable")
        end
        return
    end
    HTT._emiClockMaskWarnedNoHost = false
    HTT._emiClockMaskWarnedNoAssets = false

    setEMIClockMaskDrawHostBounds(host, innerX, innerY, innerW, innerH)
    drawHostRectSafe(
        host,
        0,
        0,
        innerW,
        innerH,
        EMI_CLOCK_MASK_BG_ALPHA,
        EMI_CLOCK_MASK_BG_R,
        EMI_CLOCK_MASK_BG_G,
        EMI_CLOCK_MASK_BG_B
    )

    if assets.background then
        drawClockTexture(host, assets.background, 0, 0, 1, 1, 1, 1)
    end

    local digitLarge = assets.digitsLarge and assets.digitsLarge[0] or nil
    local digitSmall = assets.digitsSmall and assets.digitsSmall[0] or nil
    local colon = assets.colon
    local minusTop = assets.minusTop
    local minusBottom = assets.minusBottom
    local dot = assets.dot
    local slash = assets.slash
    if not digitLarge or not digitSmall or not colon or not minusTop or not minusBottom or not dot or not slash then
        destroyEMIClockMaskDrawHost()
        return
    end

    local cfg = getClockMaskConfig(largeClock)

    local largeDigitW = digitLarge:getWidth()
    local largeDigitH = digitLarge:getHeight()
    local smallDigitW = digitSmall:getWidth()
    local smallDigitH = digitSmall:getHeight()
    if largeDigitW <= 0 or largeDigitH <= 0 or smallDigitW <= 0 or smallDigitH <= 0 then
        destroyEMIClockMaskDrawHost()
        return
    end

    local xTime = cfg.ux
    local yTime = cfg.uy
    for index = 0, 3 do
        drawMinusInDigitCell(
            host,
            minusTop,
            xTime,
            yTime,
            largeDigitW,
            largeDigitH,
            EMI_CLOCK_MASK_TEXT_ALPHA,
            EMI_CLOCK_MASK_TEXT_R,
            EMI_CLOCK_MASK_TEXT_G,
            EMI_CLOCK_MASK_TEXT_B
        )
        xTime = xTime + largeDigitW
        if index == 1 then
            xTime = xTime + cfg.colonSpacing
            drawClockTexture(
                host,
                colon,
                xTime,
                yTime,
                EMI_CLOCK_MASK_TEXT_ALPHA,
                EMI_CLOCK_MASK_TEXT_R,
                EMI_CLOCK_MASK_TEXT_G,
                EMI_CLOCK_MASK_TEXT_B
            )
            xTime = xTime + colon:getWidth() + cfg.colonSpacing
        elseif index < 3 then
            xTime = xTime + cfg.largeDigitSpacing
        end
    end

    local useCelsius = true
    if core and core.getOptionTemperatureDisplayCelsius then
        local okTempUnit, isCelsius = pcall(function()
            return core:getOptionTemperatureDisplayCelsius()
        end)
        if okTempUnit and isCelsius ~= nil then
            useCelsius = isCelsius == true
        end
    end
    local tempUnitTex = useCelsius and assets.tempC or assets.tempF
    if not tempUnitTex then
        destroyEMIClockMaskDrawHost()
        return
    end

    local xBottom = cfg.ux
    local yBottom = yTime + largeDigitH + cfg.displayVerticalSpacing

    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + smallDigitW + cfg.smallDigitSpacing
    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + smallDigitW + cfg.decimalSpacing
    drawClockTexture(
        host,
        dot,
        xBottom,
        yBottom + cfg.decimalVerticalSpacing,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + dot:getWidth() + cfg.decimalSpacing
    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + smallDigitW + cfg.degreeSpacing
    drawClockTexture(
        host,
        dot,
        xBottom,
        yBottom,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + dot:getWidth() + cfg.degreeSpacing
    drawClockTexture(
        host,
        tempUnitTex,
        xBottom,
        yBottom,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + tempUnitTex:getWidth() + cfg.tempDateSpacing

    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + smallDigitW + cfg.smallDigitSpacing
    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + smallDigitW + cfg.slashSpacing
    drawClockTexture(
        host,
        slash,
        xBottom,
        yBottom,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + slash:getWidth() + cfg.slashSpacing
    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
    xBottom = xBottom + smallDigitW + cfg.smallDigitSpacing
    drawMinusInDigitCell(
        host,
        minusBottom,
        xBottom,
        yBottom,
        smallDigitW,
        smallDigitH,
        EMI_CLOCK_MASK_TEXT_ALPHA,
        EMI_CLOCK_MASK_SUBTEXT_R,
        EMI_CLOCK_MASK_SUBTEXT_G,
        EMI_CLOCK_MASK_SUBTEXT_B
    )
end

local function captureClockSnapshot(modData, clock)
    if not modData then
        return false
    end
    if modData[EMI_CLOCK_SNAPSHOT_VALID_KEY] == true then
        return true
    end

    local visible = getClockVisibleSafe(clock)
    if visible == nil then
        visible = getPlayerDigitalWatchVisibleFallback()
    end
    if visible == nil then
        visible = false
    end

    modData[EMI_CLOCK_STATE_KEY] = visible == true
    modData[EMI_CLOCK_STATE_LEGACY_KEY] = visible == true
    modData[EMI_CLOCK_MODIFIED_KEY] = false
    modData[EMI_CLOCK_REMOVED_KEY] = false
    modData[EMI_CLOCK_SNAPSHOT_VALID_KEY] = true
    return true
end

local function clearClockSnapshot(modData)
    if not modData then
        return
    end
    modData[EMI_CLOCK_STATE_KEY] = nil
    modData[EMI_CLOCK_STATE_LEGACY_KEY] = nil
    modData[EMI_CLOCK_MODIFIED_KEY] = nil
    modData[EMI_CLOCK_REMOVED_KEY] = nil
    modData[EMI_CLOCK_SNAPSHOT_VALID_KEY] = nil
end

local function applyEMIClockInterference()
    local modData = getPlayerModDataSafe()
    local clock = getClockSafe()
    if not modData then
        return false
    end

    if clock then
        captureClockSnapshot(modData, clock)
    end
    modData[EMI_CLOCK_MODIFIED_KEY] = false
    return true
end

local function enforceClockHiddenDuringEMIPulse()
    if not isEMIClockPulseMaskActive() then
        return false
    end

    local modData = getPlayerModDataSafe()
    local clock = getClockSafe()
    if not modData or not clock then
        return false
    end

    captureClockSnapshot(modData, clock)
    if removeClockFromUIManagerSafe(clock) then
        modData[EMI_CLOCK_REMOVED_KEY] = true
        modData[EMI_CLOCK_MODIFIED_KEY] = true
    end

    local hidden = setClockVisibleSafe(clock, false)
    if hidden then
        modData[EMI_CLOCK_MODIFIED_KEY] = true
    end
    return hidden
end

local function restoreEMIClockState()
    local modData = getPlayerModDataSafe()
    if not modData then
        return false
    end
    if modData[EMI_CLOCK_SNAPSHOT_VALID_KEY] ~= true then
        clearClockSnapshot(modData)
        return true
    end

    local modified = modData[EMI_CLOCK_MODIFIED_KEY] == true
    if not modified then
        clearClockSnapshot(modData)
        return true
    end

    local clock = getClockSafe()
    if not clock then
        return false
    end

    if modData[EMI_CLOCK_REMOVED_KEY] == true then
        addClockToUIManagerSafe(clock)
    end

    local snapshotVisible = modData[EMI_CLOCK_STATE_KEY]
    if snapshotVisible == nil then
        snapshotVisible = modData[EMI_CLOCK_STATE_LEGACY_KEY]
    end

    local restored = setClockVisibleSafe(clock, snapshotVisible == true)
    if restored then
        clearClockSnapshot(modData)
    end
    return restored
end

local function syncEMIClockState(args)
    args = args or {}
    local wasEMIActive = HTT._emiClockInterferenceActive == true
    local localRelevant = HTT.IsLocalPlayerRelevantToEventState
        and HTT.IsLocalPlayerRelevantToEventState(args)
        or false
    local emiActive = args.active == true
        and tostring(args.eventId or "") == "electromagnetic_interference_event"
        and localRelevant
    HTT._emiClockInterferenceActive = emiActive

    if emiActive then
        if not wasEMIActive then
            HTT._emiClockPulsePhaseActive = false
        end
        HTT._emiClockRestorePending = false
        applyEMIClockInterference()
    else
        HTT._emiClockPulsePhaseActive = false
        destroyEMIClockMaskDrawHost()
        if restoreEMIClockState() then
            HTT._emiClockRestorePending = false
        else
            HTT._emiClockRestorePending = true
        end
    end
end

local function tickEMIClockInterference()
    if HTT._emiClockInterferenceActive then
        applyEMIClockInterference()
        enforceClockHiddenDuringEMIPulse()
        return
    end

    if HTT._emiClockRestorePending then
        if restoreEMIClockState() then
            HTT._emiClockRestorePending = false
        else
            local modData = getPlayerModDataSafe()
            if modData and modData[EMI_CLOCK_SNAPSHOT_VALID_KEY] ~= true then
                HTT._emiClockRestorePending = false
            end
        end
    else
        destroyEMIClockMaskDrawHost()
    end
end

local function tickAndRenderEMIClockInterference()
    tickEMIClockInterference()
    renderEMIClockMaskOverlay()
end

local function onEventState(args)
    args = args or {}

    local previousState = HTT.serverEvent or {}
    local wasActive = HTT.active
    local nowActive = args.active == true
    local eventId = tostring(args.eventId or "")
    local fadeMinutes = HTT.toNumber(args.fadeMinutes, 0)
    local toxicPhase = tostring(args.toxicPhase or "")
    local previousEventId = tostring(previousState.eventId or "")
    local previousFadeMinutes = HTT.toNumber(previousState.fadeMinutes, 0)
    local previousLocalRelevant = HTT.IsLocalPlayerRelevantToEventState
        and HTT.IsLocalPlayerRelevantToEventState(previousState)
        or false
    local localRelevant = HTT.IsLocalPlayerRelevantToEventState
        and HTT.IsLocalPlayerRelevantToEventState(args)
        or false
    local wasSmokeActive = previousState.active == true
        and previousEventId == "smoke_curtain_event"
        and previousLocalRelevant
    local wasToxicFogActive = previousEventId == "toxic"
        and previousLocalRelevant
        and (previousState.active == true or previousFadeMinutes > 0)
    local nowSmokeActive = nowActive and eventId == "smoke_curtain_event" and localRelevant
    local nowToxicFogActive = eventId == "toxic" and localRelevant and (nowActive or fadeMinutes > 0)
    local nowSmokeFogActive = eventId == "smoke_curtain_event" and nowActive and localRelevant

    HTT.serverEvent = args
    HTT.heliActive = nowActive and localRelevant

    if eventId == "toxic" then
        if nowActive and localRelevant and not wasActive then
            HTT.StartToxicEvent(args)
        elseif (not nowActive or not localRelevant) and wasActive then
            HTT.EndToxicEvent(args.source or "server-stop")
        end
    else
        HTT.active = nowActive and localRelevant
    end

    local fogCleared = false
    if wasSmokeActive and not nowSmokeActive and HTT.ClearSmokeCurtainFog then
        HTT.ClearSmokeCurtainFog("event-state-sync")
        fogCleared = true
    end
    if not fogCleared
        and wasToxicFogActive
        and not nowToxicFogActive
        and not nowSmokeFogActive
        and HTT.ClearEventFog
    then
        HTT.ClearEventFog("event-state-sync")
    end

    syncEMIClockState(args)

    HTT.log(string.format(
        "Client sync active=%s local=%s event=%s phase=%s source=%s center=(%.1f,%.1f,%.1f) radius=%.1f fade=%s",
        tostring(nowActive),
        tostring(localRelevant),
        tostring(args.eventId),
        toxicPhase,
        tostring(args.source),
        HTT.toNumber(args.centerX, 0),
        HTT.toNumber(args.centerY, 0),
        HTT.toNumber(args.centerZ, 0),
        HTT.toNumber(args.radius, 0),
        tostring(args.fadeMinutes)
    ))
end

local function onPlaySound(args)
    local soundName = tostring(args and args.sound or "")
    if HTT._emiClockInterferenceActive and (
        soundName == "HTT_electromagnetic_pulse_01"
        or soundName == "HTT_electromagnetic_pulse_02"
    ) then
        triggerEMIClockPulseMask()
        HTT.log("EMI clock mask pulse trigger: " .. soundName)
    end

    HTT.ClientPlaySoundNearPlayer(args)
end

local function onDebugInfo(args)
    if not args then
        return
    end

    HTT.log("Debug: " .. tostring(args.message or ""))
end

HTT.ApplyEventState = onEventState
HTT.ApplySoundCommand = onPlaySound
HTT.ApplyDebugInfo = onDebugInfo

registerEvent("OnServerCommand", function(module, command, args)
    if module ~= HTT.NET_MODULE then
        return
    end

    if command == HTT.NET_COMMAND_EVENT then
        onEventState(args)
        return
    end

    if command == HTT.NET_COMMAND_SOUND then
        onPlaySound(args)
        return
    end

    if command == HTT.NET_COMMAND_DEBUG_INFO then
        onDebugInfo(args)
    end
end)

registerEvent("OnTick", tickEMIClockInterference)

local emiClockUIHook = "none"
if registerEvent("OnPostUIDraw", tickAndRenderEMIClockInterference) then
    emiClockUIHook = "OnPostUIDraw"
elseif registerEvent("OnPreUIDraw", tickAndRenderEMIClockInterference) then
    emiClockUIHook = "OnPreUIDraw"
end

registerEvent("OnGameStart", function()
    syncEMIClockState(HTT.serverEvent or {})
    HTT.log(
        "Client network handler loaded (emiClockUIHook="
            .. emiClockUIHook
            .. ", signature="
            .. EMI_CLOCK_SCRIPT_SIGNATURE
            .. ")"
    )
end)
