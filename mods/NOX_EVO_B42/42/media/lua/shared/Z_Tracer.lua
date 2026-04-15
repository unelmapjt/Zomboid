Z_TRACER = {}
local unpackFn = rawget(table, "unpack") or unpack
Z_TRACER.Config = {
    TRACE_ENABLED = true,
    TRACE_LEVEL = "INFO"
}

local LEVEL_PRIORITY = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local function getTraceLevel(traceType, action)
    if traceType == "FATAL" then
        return "ERROR"
    end
    if action == "START" or action == "END" then
        return "DEBUG"
    end
    return "INFO"
end

local function emitTrace(traceType, name, action, optionalLevel)
    local config = Z_TRACER.Config or {}
    if config.TRACE_ENABLED == false then
        return
    end

    local msgLevel = tostring(optionalLevel or getTraceLevel(traceType, action)):upper()
    local currentLevel = tostring(config.TRACE_LEVEL or "INFO"):upper()
    local currentPriority = LEVEL_PRIORITY[currentLevel] or LEVEL_PRIORITY.INFO
    local msgPriority = LEVEL_PRIORITY[msgLevel] or LEVEL_PRIORITY.INFO
    if msgPriority < currentPriority then
        return
    end

    print(string.format(
        '{"Z_TRACE":true, "level":"%s", "type":"%s", "target":"%s", "action":"%s"}',
        msgLevel, traceType, name, action
    ))
end

-- 1. イベント・ライフサイクル監視
local function WrapCallback(eventName, originalFunc)
    return function(...)
        emitTrace("EVENT", eventName, "START")
        local result = {pcall(originalFunc, ...)}
        if not result[1] then
            emitTrace("FATAL", eventName, "CRASH: " .. tostring(result[2]))
            error(result[2])
        else
            emitTrace("EVENT", eventName, "END")
        end
        return unpackFn(result, 2)
    end
end

local excluded_events = { OnTick = true, OnPlayerUpdate = true, OnRenderTick = true }
for eventName, eventObj in pairs(Events) do
    if type(eventObj) == "table" and eventObj.Add and not excluded_events[eventName] and not eventObj.__z_wrapped then
        local originalAdd = eventObj.Add
        eventObj.Add = function(self, func)
            originalAdd(self, WrapCallback(eventName, func))
        end
        eventObj.__z_wrapped = true
    end
end

-- 2. ネットワーク境界監視
if isClient() and not _G.__z_sendClientCommand_wrapped then
    _G.__z_orig_sendClientCommand = _G.__z_orig_sendClientCommand or sendClientCommand
    sendClientCommand = function(module, command, args)
        emitTrace("NET_SEND", module .. ":" .. command, "C2S")
        _G.__z_orig_sendClientCommand(module, command, args)
    end
    _G.__z_sendClientCommand_wrapped = true
end

if isServer() and not _G.__z_sendServerCommand_wrapped then
    _G.__z_orig_sendServerCommand = _G.__z_orig_sendServerCommand or sendServerCommand
    sendServerCommand = function(module, command, args)
        emitTrace("NET_SEND", module .. ":" .. command, "S2C")
        _G.__z_orig_sendServerCommand(module, command, args)
    end
    _G.__z_sendServerCommand_wrapped = true
end