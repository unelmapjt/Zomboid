local ModManagerData = {
    data = {}, isQuerying = false
}

local function trim(s)
    if not s then return "" end
    return s:match'^%s*(.-)%s*$'
end

local function cleanModId(id)
    if not id then return "" end
    return id:match("^\\?(.+)") or id
end

function ModManagerData:load()
    self.data = {
        version = 1,
        mods = {},
        alerts = {},
        workshop = {
            usage = {
                time = 0,
                requests = 0,
            },
            mods = {}
        }
    }

    local reader = getFileReader("ModManager/ModListData.lua", false)
    if reader then
        local content = ""
        local line = reader:readLine()
        while line do
            content = content .. line .. "\n"
            line = reader:readLine()
        end
        reader:close()

        if content ~= "" then
            ---@diagnostic disable-next-line: deprecated
            local func = loadstring(content)
            if func then
                local res = func()
                if res then self.data = res end
            end
        end
    else
        reader = getFileReader("modManager.ini", false)
        if reader then
            local line, path = reader:readLine(), {}
            local currentAlertModId = nil
            local migrated = false

            local oldModsList = {}
            local oldHiddenMap = {}

            while line ~= nil do
                line = trim(line)
                migrated = true

                if line:match("^%s*%}%s*,?%s*$") then
                    if path[#path] == currentAlertModId then
                        currentAlertModId = nil
                    end
                    table.remove(path)
                else
                    local sectionName = line:match("^%s*([%w_]+)%s*=%s*%{")
                    if sectionName then
                        table.insert(path, sectionName)
                    else
                        local modIdMatch = line:match('^%s*"([^"]+)":%s*%{')
                        if modIdMatch then
                            table.insert(path, modIdMatch)
                            if path[1] == 'alerts' then
                                currentAlertModId = modIdMatch
                                self.data.alerts[currentAlertModId] = {}
                            end
                        else
                            if #path > 0 then
                                local key, value = line:match('^%s*([%w_]+)%s*=%s*"?([^",]+)"?')

                                if key and value then
                                    if path[1] == 'workshop' and path[2] == 'usage' then
                                        local targetTable = self.data.workshop.usage
                                        local numValue = tonumber(value)
                                        targetTable[key] = numValue or value
                                    elseif path[1] == 'workshop' and path[2] == 'mods' and path[3] then
                                        local modId = path[3]
                                        if not self.data.workshop.mods[modId] then
                                            self.data.workshop.mods[modId] = {}
                                        end
                                        local targetTable = self.data.workshop.mods[modId]
                                        local numValue = tonumber(value)
                                        targetTable[key] = numValue or value
                                    elseif path[1] == 'alerts' and currentAlertModId then
                                        local targetTable = self.data.alerts[currentAlertModId]
                                        if key == 'seen' then
                                            targetTable[key] = (value == "true")
                                        else
                                            local numValue = tonumber(value)
                                            targetTable[key] = numValue or value
                                        end
                                    end
                                elseif path[1] == 'mods' then
                                     local modId = line:match('^"([^"]+)"')
                                     if modId then table.insert(oldModsList, modId) end
                                elseif path[1] == 'hidden' then
                                    local modId = line:match('^"([^"]+)"')
                                    if modId then oldHiddenMap[modId] = true end
                                end
                            end
                        end
                    end
                end
                line = reader:readLine()
            end
            reader:close()

            if migrated then
                for i, modID in ipairs(oldModsList) do
                    local cleanId = cleanModId(modID)
                    self.data.mods[cleanId] = {
                        hidden = (oldHiddenMap[modID] == true),
                        index = i
                    }
                end

                self.data.workshop.usage.requests = 0
                self:save()
                
                local writer = getFileWriter("modManager.ini", false, false)
                if writer then writer:close() end
            end
        end
    end

    if self.data.mods then
        local cleaned = {}
        for id, data in pairs(self.data.mods) do
            cleaned[cleanModId(id)] = data
        end
        self.data.mods = cleaned
    end

    if self.data.alerts then
        local cleaned = {}
        for id, data in pairs(self.data.alerts) do
            cleaned[cleanModId(id)] = data
        end
        self.data.alerts = cleaned
    end

    if self.data.workshop and self.data.workshop.mods then
        local cleaned = {}
        for id, data in pairs(self.data.workshop.mods) do
            cleaned[cleanModId(id)] = data
        end
        self.data.workshop.mods = cleaned
    end

    return self.data
end

function ModManagerData:save()
    local file = getFileWriter("ModManager/ModListData.lua", true, false)
    if not file then return end

    file:write("return {\r\n")
    file:write("    version = " .. tostring(self.data.version or 1) .. ",\r\n")
    
    file:write("    mods = {\r\n")
    local sortedMods = {}
    for k, v in pairs(self.data.mods or {}) do
        table.insert(sortedMods, { id = k, data = v })
    end
    table.sort(sortedMods, function(a, b) return (a.data.index or 0) < (b.data.index or 0) end)
    
    for _, item in ipairs(sortedMods) do
        file:write('        ["' .. item.id .. '"] = {\r\n')
        file:write('            hidden = ' .. tostring(item.data.hidden) .. ',\r\n')
        file:write('            index = ' .. tostring(item.data.index) .. ',\r\n')
        file:write('        },\r\n')
    end
    file:write("    },\r\n")

    file:write("    alerts = {\r\n")
    local alertKeys = {}
    for k in pairs(self.data.alerts or {}) do table.insert(alertKeys, k) end
    table.sort(alertKeys)
    for _, modID in ipairs(alertKeys) do
        local data = self.data.alerts[modID]
        file:write('        ["' .. modID .. '"] = {\r\n')
        file:write('            workshopID = ' .. string.format("%.0f", data.workshopID or 0) .. ',\r\n')
        file:write('            lastUpdate = ' .. string.format("%.0f", data.lastUpdate or 0) .. ',\r\n')
        file:write('            seen = ' .. tostring(data.seen or false) .. ',\r\n')
        file:write('        },\r\n')
    end
    file:write("    },\r\n")

    file:write("    workshop = {\r\n")
    file:write("        usage = {\r\n")
    local usage = self.data.workshop and self.data.workshop.usage or { time = 0, requests = 0 }
    file:write("            time = " .. string.format("%.0f", usage.time or 0) .. ",\r\n")
    file:write("            requests = " .. string.format("%.0f", usage.requests or 0) .. ",\r\n")
    file:write("        },\r\n")

    file:write("        mods = {\r\n")
    local wsMods = self.data.workshop and self.data.workshop.mods or {}
    local wsKeys = {}
    for k in pairs(wsMods) do table.insert(wsKeys, k) end
    table.sort(wsKeys)
    for _, modID in ipairs(wsKeys) do
        local data = wsMods[modID]
        file:write('            ["' .. modID .. '"] = {\r\n')
        file:write('                workshopID = ' .. string.format("%.0f", data.workshopID or 0) .. ',\r\n')
        file:write('                lastUpdate = ' .. string.format("%.0f", data.lastUpdate or 0) .. ',\r\n')
        file:write('                state = "' .. tostring(data.state or "") .. '",\r\n')
        file:write('            },\r\n')
    end
    file:write("        }\r\n")
    file:write("    }\r\n")
    file:write("}\r\n")

    file:close()
end

function ModManagerData:getWorkshopData()
    return self.data and self.data.workshop
end

function ModManagerData:getAlertsData()
    return self.data and self.data.alerts
end

function ModManagerData:getModWorkshopInfo(modID)
    if self.data and self.data.workshop and self.data.workshop.mods and self.data.workshop.mods[modID] then
        return self.data.workshop.mods[modID]
    end
    return nil
end

function ModManagerData:updateWorkshopData(steamInfo, modMap)
    if not self.data.workshop then
        self.data.workshop = { usage = { time = 0, requests = 0 }, mods = {} }
    end
    if not self.data.workshop.mods then
        self.data.workshop.mods = {}
    end

    for i = 0, steamInfo:size() - 1 do
        local details = steamInfo:get(i)
        local wid = details:getIDString()
        local mods = modMap and modMap[wid]

        if mods then
            for _, modInfo in ipairs(mods) do
                local modID = modInfo:getId()
                self.data.workshop.mods[modID] = {
                    workshopID = tonumber(wid),
                    lastUpdate = details:getTimeUpdated(),
                    state = details:getState(),
                }
            end
        end
    end
end

function ModManagerData:updateUsageStats(numRequests)
    if not self.data.workshop then self:load() end
    if not self.data.workshop.usage then
        self.data.workshop.usage = { time = 0, requests = 0 }
    end
    
    local now = os.time()
    if now - (self.data.workshop.usage.time or 0) > 3600 then
        self.data.workshop.usage.requests = 0
    end
    
    self.data.workshop.usage.time = now
    self.data.workshop.usage.requests = (self.data.workshop.usage.requests or 0) + numRequests
end

return ModManagerData