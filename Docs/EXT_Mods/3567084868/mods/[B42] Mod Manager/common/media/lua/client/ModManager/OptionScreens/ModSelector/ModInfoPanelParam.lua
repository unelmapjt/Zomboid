require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModInfoPanel"

local ModManagerData = require "ModManager/Utilities/ModListData"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

ModInfoPanel.Param = ISPanelJoypad:derive("ModInfoPanelParam")

function ModInfoPanel.Param:render()
    self:drawRectBorder(0, 0, self.borderX, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.name, self.borderX - UI_BORDER_SPACING - self.labelWidth, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)

    if self.modInfo == nil then return end

    if self.type == "Status" then
        if self.parent.parent.model:isModActive(self.modInfo:getId()) then
            self:drawText(getText("UI_mods_ModEnabled"), self.borderX+UI_BORDER_SPACING, 2, 0.0, 0.9, 0.0, 0.9, UIFont.Small)
        else
            self:drawText(getText("UI_mods_ModDisabled"), self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.0, 0.0, 0.9, UIFont.Small)
        end
    elseif self.type == "Version" then
        local versionText = self.modInfo:getModVersion() or ""
        local finalText = ""
        local r, g, b = 0.9, 0.9, 0.9
        
        local isQuerying = ModManagerData.isQuerying and self.workshopID ~= ""
        
        if isQuerying then
            finalText = versionText
        else
            local statusText = ""
            if self.workshopState == "NeedsUpdate" then
                statusText = getText("UI_modselector_status_needsUpdate")
                r, g, b = 0.2, 0.6, 1.0
            elseif self.workshopState == "Installed" then
                statusText = getText("UI_modselector_status_installed")
            end

            if statusText ~= "" then
                if versionText ~= "" then
                    local formattedStatus = statusText:gsub("!", ""):lower()
                    finalText = versionText .. " (" .. formattedStatus .. ")"
                else
                    finalText = statusText
                end
            else
                finalText = versionText
            end
        end

        local textX = self.borderX + UI_BORDER_SPACING
        self:drawText(finalText, textX, 2, r, g, b, 0.9, UIFont.Small)

        if isQuerying then
            local time = getTimestampMs()
            local activeDotIndex = math.floor(time / 300) % 3 + 1
            
            local textLen = 0
            if finalText ~= "" then
                textLen = getTextManager():MeasureStringX(UIFont.Small, finalText) + 4
            end
            
            local dotX = textX + textLen
            local dotWidth = getTextManager():MeasureStringX(UIFont.Small, ".") + 1

            for i = 1, 3 do
                local dr, dg, db = 0.4, 0.4, 0.4
                if i == activeDotIndex then
                    dr, dg, db = 0.9, 0.9, 0.9
                end
                
                self:drawText(".", dotX, 2, dr, dg, db, 0.9, UIFont.Small)
                dotX = dotX + dotWidth
            end
        end

        if self.isUpdateRequired and not isQuerying then
            local textLen = getTextManager():MeasureStringX(UIFont.Small, finalText)
            local lineY = 1 + FONT_HGT_SMALL
            
            local isMouseOverText = self:isMouseOver() and self:getMouseX() > textX and self:getMouseX() < textX + textLen and self:getMouseY() > 2 and self:getMouseY() < 2 + FONT_HGT_SMALL + 1
            if not isMouseOverText then
                self:drawRectBorder(textX, lineY, textLen, 1, 0.9, r, g, b)
            elseif self.pressed then
                activateSteamOverlayToWorkshopItem(self.workshopID)
            end
        end

    elseif self.type == "Author" then
        self:drawText(self.modInfo:getAuthor(), self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
    elseif self.type == "ModID" then
        self:drawText(self.modInfo:getId(), self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
    elseif self.type == "WorkshopID" then
        self:drawText(self.workshopID, self.borderX+UI_BORDER_SPACING, 2, 0.2, 0.6, 1.0, 0.9, UIFont.Small)
        if self.workshopID ~= "" and not (self:isMouseOver() and self:getMouseX() > self.borderX+UI_BORDER_SPACING and self:getMouseX() < self.borderX+UI_BORDER_SPACING + self.workshopIDLen
                and self:getMouseY() > 2 and self:getMouseY() < 2 + FONT_HGT_SMALL + 1) then
            self:drawRectBorder(self.borderX+UI_BORDER_SPACING, 1+FONT_HGT_SMALL, self.workshopIDLen, 1, 0.9, 0.2, 0.6, 1.0)
        elseif self.workshopID ~= "" and self.pressed then
            local source = self.modInfo:getSource()
            if source == "Workshop" or source == "Mods" then
                showFolderInDesktop(self.modInfo:getDir())
            else
                activateSteamOverlayToWorkshopItem(self.workshopID)
            end
        end
    elseif self.type == "LastUpdate" then
        local isQuerying = ModManagerData.isQuerying and self.workshopID ~= ""
        local textX = self.borderX + UI_BORDER_SPACING

        if isQuerying then
            local time = getTimestampMs()
            local activeDotIndex = math.floor(time / 300) % 3 + 1
            local dotWidth = getTextManager():MeasureStringX(UIFont.Small, ".") + 1
            local dotX = textX

            for i = 1, 3 do
                local dr, dg, db = 0.4, 0.4, 0.4
                if i == activeDotIndex then
                    dr, dg, db = 0.9, 0.9, 0.9
                end
                self:drawText(".", dotX, 2, dr, dg, db, 0.9, UIFont.Small)
                dotX = dotX + dotWidth
            end
        else
            self:drawText(self.formattedDate, textX, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
        end
    elseif self.type == "ZomboidVersion" then
        if self.modInfo:isAvailableSelf() then
            self:drawText(self.zomboidVersion, self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
        else
            self:drawText("AVAILABLE ONLY IN DEBUG (mod must be updated to " .. getBreakModGameVersion():toString() .. "+ version)", self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.0, 0.0, 0.9, UIFont.Small)
        end
    end
    self.pressed = false
end

function ModInfoPanel.Param:openUrl(button, url)
    if button.internal == "YES" then
        openUrl(url)
    end
end

function ModInfoPanel.Param:onMouseDown(x, y)
    self.pressed = true
end

function ModInfoPanel.Param:formatDate(seconds)
    if not seconds or seconds == 0 then return "" end
    
    local millis = seconds * 1000.0
    local nowMillis = getTimestampMs()

    local sdfComponents = SimpleDateFormat.new("d M yyyy H m")
    local dateStr = sdfComponents:format(millis)
    
    local values = {}
    for v in string.gmatch(dateStr, "%S+") do table.insert(values, tonumber(v)) end
    local day, month, year, hour, min = values[1], values[2], values[3], values[4], values[5]

    local sdfCompare = SimpleDateFormat.new("yyyyMMdd")
    local dateKey = sdfCompare:format(millis)
    local nowKey = sdfCompare:format(nowMillis)
    local yesterdayKey = sdfCompare:format(nowMillis - 86400000.0)

    local timeFormat
    if dateKey == nowKey then
        timeFormat = getText("UI_modinfopanel_TimeFormat_Today")
    elseif dateKey == yesterdayKey then
        timeFormat = getText("UI_modinfopanel_TimeFormat_Yesterday")
    elseif year == tonumber(os.date("%Y")) then
        timeFormat = getText("UI_modinfopanel_TimeFormat_ThisYear")
    else
        timeFormat = getText("UI_modinfopanel_TimeFormat_OtherYears")
    end

    local monthStr = getText("UI_modinfopanel_Month_Short_" .. month)

    local h12, ampm = hour, ""
    if h12 >= 12 then
        ampm = getText("UI_modinfopanel_PM")
        if h12 > 12 then h12 = h12 - 12 end
    else
        ampm = getText("UI_modinfopanel_AM")
        if h12 == 0 then h12 = 12 end
    end

    local res = timeFormat
    res = res:gsub("{day}", day)
    res = res:gsub("{month}", monthStr)
    res = res:gsub("{year}", year)
    res = res:gsub("{hour24}", string.format("%02d", hour))
    res = res:gsub("{hour12}", h12)
    res = res:gsub("{min}", string.format("%02d", min))
    res = res:gsub("{ampm}", ampm)

    return res
end

function ModInfoPanel.Param:setModInfo(modInfo)
    self.modInfo = modInfo

    self.zomboidVersion = (self.modInfo:getVersionMin() and self.modInfo:getVersionMin():toString() or "**") .. " - " .. (self.modInfo:getVersionMax() and self.modInfo:getVersionMax():toString() or "**")
    
    local model = self.parent.parent.model
    local modId = modInfo:getId()
    local modData = model.mods[modId]

    if modData then
        self.workshopID = modData.workshopIDStr or ""
        self.workshopState = modData.workshopState or ""
        self.isUpdateRequired = (self.workshopState == "NeedsUpdate")
        self.formattedDate = self:formatDate(modData.timeUpdated)
    else
        self.workshopID = ""
        self.workshopState = ""
        self.isUpdateRequired = false
        self.formattedDate = ""
    end

    if self.type == "WorkshopID" then
        local source = self.modInfo:getSource()
        if source == "Workshop" or source == "Mods" then
            self.name = getText("UI_modinfopanel_LocalPath")
            self.workshopID = self.modInfo:getDir()
        else
            self.name = getText("UI_modinfopanel_WorkshopID")
        end
        self.labelWidth = getTextManager():MeasureStringX(UIFont.Small, self.name)
    end

    local availableWidth = self.width - self.borderX - UI_BORDER_SPACING * 2
    if getTextManager():MeasureStringX(UIFont.Small, self.workshopID) > availableWidth then
        local dotWidth = getTextManager():MeasureStringX(UIFont.Small, "...")
        while self.workshopID ~= "" and getTextManager():MeasureStringX(UIFont.Small, self.workshopID) > (availableWidth - dotWidth) do
            self.workshopID = string.sub(self.workshopID, 1, #self.workshopID - 1)
        end
        self.workshopID = self.workshopID .. "..."
    end

    self.workshopIDLen = getTextManager():MeasureStringX(UIFont.Small, self.workshopID)
end

function ModInfoPanel.Param:new(x, y, width, type)
    local o = ISPanelJoypad:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.type = type
    o.name = getText("UI_modinfopanel_" .. type)
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.tickTexture = getTexture("media/ui/inventoryPanes/Tickbox_Tick.png")
    o.zomboidVersion = ""
    o.workshopID = ""
    o.workshopIDLen = 0
    o.borderX = width / 4.0
    return o
end