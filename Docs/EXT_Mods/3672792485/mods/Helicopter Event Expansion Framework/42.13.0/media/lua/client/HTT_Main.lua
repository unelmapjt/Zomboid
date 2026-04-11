require "HTT_Core"
require "HTT_ClientOptions"

HTT = HTT or {}

HTT.active = HTT.active or false
HTT.heliActive = HTT.heliActive or false
HTT.serverEvent = HTT.serverEvent or nil

local function getLocalPlayerSafe()
    if not getPlayer then
        return nil
    end
    return getPlayer()
end

function HTT.IsLocalPlayerFollowTarget(onlineId)
    local wantedId = HTT.toNumber(onlineId, nil)
    if wantedId == nil then
        return false
    end

    local player = getLocalPlayerSafe()
    if not player or not player.getOnlineID then
        return false
    end

    local localOnlineId = HTT.toNumber(player:getOnlineID(), nil)
    return localOnlineId ~= nil and localOnlineId == wantedId
end

function HTT.IsLocalPlayerWithinEventRadius(state, extraRadius)
    if type(state) ~= "table" then
        return false
    end

    local player = getLocalPlayerSafe()
    if not player then
        return false
    end

    local centerX = HTT.toNumber(state.centerX, nil)
    local centerY = HTT.toNumber(state.centerY, nil)
    if centerX == nil or centerY == nil then
        return false
    end

    local radius = HTT.toNumber(state.radius, HTT.Config.DefaultSoundRadius)
    radius = radius + math.max(0, HTT.toNumber(extraRadius, 0))
    if radius <= 0 then
        return false
    end

    local dx = player:getX() - centerX
    local dy = player:getY() - centerY
    return (dx * dx + dy * dy) <= (radius * radius)
end

function HTT.IsLocalPlayerRelevantToEventState(state, extraRadius)
    if type(state) ~= "table" then
        return false
    end

    if HTT.IsLocalPlayerFollowTarget(state.followOnlineId) then
        return true
    end

    return HTT.IsLocalPlayerWithinEventRadius(state, extraRadius)
end

HTT.log("HTT client main loaded")
