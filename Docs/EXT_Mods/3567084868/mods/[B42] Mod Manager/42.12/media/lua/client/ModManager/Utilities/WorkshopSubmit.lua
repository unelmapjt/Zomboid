require "OptionScreens/WorkshopSubmitScreen"

local function formatChangelog(version, content)
    local result = "[h2][b]" .. version .. "[/b][/h2]\n"
    local lines, inList = luautils.split(content, "\n"), false

    for i = 1, #lines do
        local line = lines[i]
        local trimmed = string.trim(line)
        if trimmed ~= "" then
            local isListItem = string.find(trimmed, "^-") or string.find(trimmed, "^•")
            
            if isListItem then
                if not inList then
                    result = result .. "[list]\n"; inList = true
                end
                local cleanLine = string.gsub(trimmed, "^[-•]%s*", "")
                result = result .. "[*]" .. cleanLine .. "\n"
            else
                if inList then
                    result = result .. "[/list]\n"; inList = false
                end
                result = result .. trimmed .. "\n"
            end
        end
    end

    if inList then
        result = result .. "[/list]\n"
    end

    return result
end

local function getLatestChangelog(modID)
    local reader = getModFileReader("\\" .. modID, "ChangeLog.txt", false)
    if not reader then
        reader = getModFileReader("\\" .. modID, "ChangeLog.md", false)
    end

    if not reader then return nil end

    local entries = {}
    local currentEntry = nil

    local line = reader:readLine()
    while line ~= nil do
        local trimmed = string.trim(line)
        local versionMatch = string.match(trimmed, "^%[%s*(.-)%s*%]$")
        local isSeparator = string.match(trimmed, "^%[%s*%-%-+%s*%]$")
        
        if not versionMatch then
            versionMatch = string.match(trimmed, "^###%s*(.-)%s*###$")
        end
        if not isSeparator then
            isSeparator = string.match(trimmed, "^#$")
        end

        if versionMatch then
            if currentEntry then
                table.insert(entries, currentEntry)
            end
            if versionMatch ~= "ALERT_CONFIG" and not isSeparator then
                currentEntry = { version = versionMatch, content = "" }
            else
                currentEntry = nil
            end
        elseif isSeparator then
            if currentEntry then
                table.insert(entries, currentEntry)
                currentEntry = nil
            end
        elseif currentEntry then
            if trimmed ~= "" then
                currentEntry.content = currentEntry.content .. trimmed .. "\n"
            end
        end

        line = reader:readLine()
    end
    
    if currentEntry then
        table.insert(entries, currentEntry)
    end
    
    reader:close()

    if #entries > 0 then
        local lastEntry = entries[#entries]
        if lastEntry.content ~= "" then
            return formatChangelog(lastEntry.version, lastEntry.content)
        end
    end

    return nil
end

local function updateChangeNotes(workshopItem)
    if not workshopItem then return end

    local modID, desc = nil, workshopItem:getSubmitDescription()

    for line in string.gmatch(desc, "[^\r\n]+") do
        modID = string.match(line, "^Mod ID:%s*(.+)$")
        if modID then break end
    end

    if not modID then return end

    local changeLog = getLatestChangelog(modID)
    if changeLog then
        workshopItem:setChangeNote(changeLog)
    end
end

local original_create = WorkshopSubmitScreen.create
function WorkshopSubmitScreen:create()
    original_create(self)
    
    local original_setWorkshopItem = self.page2.setWorkshopItem
    function self.page2:setWorkshopItem(item)
        original_setWorkshopItem(self, item); updateChangeNotes(self.parent.item)
    end
end