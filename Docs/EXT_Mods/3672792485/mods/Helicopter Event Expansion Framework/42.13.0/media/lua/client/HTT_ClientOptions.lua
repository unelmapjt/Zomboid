require "HTT_Core"

local modOptionsOk = pcall(require, "PZAPI/ModOptions")
if not modOptionsOk then
    return
end

HTT = HTT or {}
HTT.ClientOptions = HTT.ClientOptions or {}

if HTT._clientOptionsLoaded then
    return
end
HTT._clientOptionsLoaded = true

local ClientOptions = HTT.ClientOptions
ClientOptions.MOD_OPTIONS_ID = "HTT_Client"
ClientOptions.DEFAULT_EVENT_VOLUME = 100
ClientOptions._eventVolume = ClientOptions._eventVolume or ClientOptions.DEFAULT_EVENT_VOLUME
ClientOptions._registered = ClientOptions._registered or false

local function clampVolumePercent(value)
    local num = HTT.toNumber(value, ClientOptions.DEFAULT_EVENT_VOLUME)
    if num < 0 then
        num = 0
    end
    if num > 100 then
        num = 100
    end
    return math.floor(num + 0.5)
end

local function splitByPipe(line)
    if luautils and luautils.split then
        return luautils.split(line, "|")
    end
    local out = {}
    for part in tostring(line):gmatch("([^|]+)") do
        out[#out + 1] = part
    end
    return out
end

local function loadSavedEventVolume(defaultValue)
    if not getFileReader then
        return defaultValue
    end

    local file = getFileReader("ModOptions.ini", true)
    if not file then
        return defaultValue
    end

    local value = defaultValue
    while true do
        local line = file:readLine()
        if not line then
            break
        end
        local t = splitByPipe(line)
        if t[1] == "slider" and t[2] == ClientOptions.MOD_OPTIONS_ID and t[3] == "EventSoundVolume" then
            local parsed = tonumber(t[4])
            if parsed then
                value = parsed
            end
            break
        end
    end

    file:close()
    return clampVolumePercent(value)
end

function ClientOptions.getEventVolumePercent()
    return clampVolumePercent(ClientOptions._eventVolume)
end

function ClientOptions.getEventVolumeMultiplier()
    return ClientOptions.getEventVolumePercent() / 100
end

function HTT.GetClientEventSoundVolumePercent()
    return ClientOptions.getEventVolumePercent()
end

function HTT.GetClientEventSoundVolumeMultiplier()
    return ClientOptions.getEventVolumeMultiplier()
end

local function applyEventVolume(value)
    local clamped = clampVolumePercent(value)
    ClientOptions._eventVolume = clamped
    HTT.Config.EventSoundVolumePercent = clamped
end

local function bindEventVolumeCallback(option)
    if not option then
        return
    end

    option.onChangeApply = function(selfOrValue, maybeValue)
        local value = maybeValue
        if value == nil then
            value = selfOrValue
        end
        if type(value) == "table" then
            value = value.value
        end
        applyEventVolume(value)
    end
end

local function registerModOptions()
    if ClientOptions._registered then
        return
    end
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then
        return
    end

    local initial = loadSavedEventVolume(ClientOptions.DEFAULT_EVENT_VOLUME)
    applyEventVolume(initial)

    local options = PZAPI.ModOptions:getOptions(ClientOptions.MOD_OPTIONS_ID)
    if not options then
        options = PZAPI.ModOptions:create(ClientOptions.MOD_OPTIONS_ID, "IGUI_HTT_Opt_Mod_Title")
    end
    if not options then
        return
    end

    local existing = options.getOption and options:getOption("EventSoundVolume") or nil
    if existing then
        existing.value = clampVolumePercent(existing.value)
        applyEventVolume(existing.value)
        bindEventVolumeCallback(existing)
        ClientOptions._registered = true
        return
    end

    options:addTitle("IGUI_HTT_Opt_Audio_Title")
    options:addDescription("IGUI_HTT_Opt_Audio_Desc")

    local slider = options:addSlider(
        "EventSoundVolume",
        "IGUI_HTT_Opt_EventVolume",
        0,
        100,
        5,
        initial,
        "IGUI_HTT_Opt_EventVolume_tt"
    )

    bindEventVolumeCallback(slider)

    ClientOptions._registered = true
end

registerModOptions()

local function registerEvent(eventName, callback)
    if not Events then
        return false
    end
    local evt = Events[eventName]
    if evt and evt.Add then
        evt.Add(callback)
        return true
    end
    return false
end

registerEvent("OnGameStart", function()
    registerModOptions()
end)
