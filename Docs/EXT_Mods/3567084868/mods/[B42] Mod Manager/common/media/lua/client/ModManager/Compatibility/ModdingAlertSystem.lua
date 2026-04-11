require "OptionScreens/ModSelector/ModSelector"

local alertSystem = require "chuckleberryFinnModdingAlertSystem"
local changelog_handler = require "chuckleberryFinnModding_modChangelog"
local ModManagerData = require "ModManager/Utilities/ModListData"

if alertSystem and changelog_handler then
    local original_initialise = alertSystem.initialise

    local function formatDate(seconds)
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

        local h12 = hour
        local ampm = ""
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

    function alertSystem:markCurrentAlertAsSeen()
        if self.alertSelected > 0 and self.alertsLoaded and self.alertsLoaded[self.alertSelected] then
            local modID = self.alertsLoaded[self.alertSelected]; local alertData = self.latestAlerts[modID]
            if alertData and not alertData.alreadyStored then
                alertData.alreadyStored = true; self.alertsOld = (self.alertsOld or 0) + 1
                if ModManagerData.data.alerts and ModManagerData.data.alerts[modID] then
                    ModManagerData.data.alerts[modID].seen = true
                    ModManagerData:save()
                end
            end
        end
    end

    local original_onMouseDown = alertSystem.onMouseDown
    function alertSystem:onMouseDown(x, y)
        if y <= 32 then
            local click = 0
            if (x >= self.alertLeftX+8 and x <= self.alertLeftX+24) then click = -1 end
            if (x >= self.alertRightX+8 and x <= self.alertRightX+24) then click = 1 end
            if click ~= 0 then
                self:markCurrentAlertAsSeen()
            end
        end
        return original_onMouseDown(self, x, y)
    end

    local original_onMouseWheel = alertSystem.onMouseWheel
    function alertSystem:onMouseWheel(del)
        local x, y = self:getMouseX(), self:getMouseY()
        if x >= self.alertLeftX and x <= self.alertLeftX+self.alertBarSpan and y >= 10 and y <= 10+12 then
            self:markCurrentAlertAsSeen()
        end
        return original_onMouseWheel(self, del)
    end

    local original_onClickCollapse = alertSystem.onClickCollapse
    function alertSystem:onClickCollapse(...)
        original_onClickCollapse(self, ...); if self.collapsed then
            self:markCurrentAlertAsSeen()
        end
    end

    function alertSystem:processUpdates()
        local twoWeeksAgo = os.time() - 14 * 24 * 60 * 60
        local existingAlerts = ModManagerData:getAlertsData() or {}
        local newAlerts = {}
        local workshopMods = ModManagerData.data.workshop and ModManagerData.data.workshop.mods or {}

        for modID, wsData in pairs(workshopMods) do
            local ts = wsData.lastUpdate
            if ts and ts >= twoWeeksAgo then
                local modInfo = getModInfoByID(modID)
                if modInfo then
                    local alerts = changelog_handler.fetchMod(modID)
                    if alerts and #alerts > 0 then
                        local currentEntry = existingAlerts[modID]
                        if currentEntry then
                            if currentEntry.lastUpdate ~= ts then
                                newAlerts[modID] = { workshopID = wsData.workshopID, lastUpdate = ts, seen = false }
                            else
                                newAlerts[modID] = currentEntry
                            end
                        else
                            newAlerts[modID] = { workshopID = wsData.workshopID, lastUpdate = ts, seen = false }
                        end
                    end
                end
            end
        end

        ModManagerData.data.alerts = newAlerts; ModManagerData:save()

        local sortedItems = {}
        for modID, data in pairs(newAlerts) do
            table.insert(sortedItems, { modID = modID, ts = data.lastUpdate })
        end
        table.sort(sortedItems, function(a, b) return a.ts > b.ts end)

        self.alertsLoaded = {}
        self.latestAlerts = {}
        self.alertsLayout = {}
        self.alertsOld = 0

        for _, item in ipairs(sortedItems) do
            local modID = item.modID
            local modInfo = getModInfoByID(modID)

            if modInfo then
                local alerts = changelog_handler.fetchMod(modID)
                local modName = modInfo:getName()
                local modIcon = modInfo:getIcon() and getTexture(modInfo:getIcon())
                local modAuthor = modInfo:getAuthor()
                local seen = newAlerts[modID].seen

                self.latestAlerts[modID] = {
                    modName = modName,
                    alerts = alerts,
                    icon = modIcon,
                    modAuthor = modAuthor,
                    alreadyStored = seen,
                    ts = item.ts
                }
                table.insert(self.alertsLoaded, modID)
                if seen then
                    self.alertsOld = self.alertsOld + 1
                end
            end
        end

        if #self.alertsLoaded > 0 then
            self.alertSelected = 1
            if self["linkButton1"] then
                self:updateButtons()
            end
        end
    end

    function alertSystem:initialise()
        original_initialise(self)

        self.latestAlerts = {}
        self.alertsLoaded = {}
        self.alertSelected = 0
        self.alertsOld = 0
        self.alertsLayout = {}

        if getSteamModeActive() then
            if not ModManagerData.data.workshop then
                ModManagerData:load()
            end
            
            self:processUpdates()
            
            if Events.OnModManagerWorkshopUpdate then
                Events.OnModManagerWorkshopUpdate.Add(function()
                    if MainScreen.instance and MainScreen.instance.alertSystem then
                        MainScreen.instance.alertSystem:processUpdates()
                    end
                end)
            end
        end
    end

    function alertSystem:prerender()
        ISPanelJoypad.prerender(self)

        local collapseWidth = not self.collapsed and self.width or self.collapse.width+10
        self:drawRect(0, 0, collapseWidth, self.height, 0.8, 0, 0, 0)
        self:drawRectBorder(0, 0, collapseWidth, self.height, 0.8, 1, 1, 1)

        if not self.collapsed and self.alertSelected > 0 and self.alertsLoaded and #self.alertsLoaded > 0 then
            local alertModID = self.alertsLoaded[self.alertSelected]
            local alertModData = self.latestAlerts[alertModID]
            if not alertModData then return end

            local modName = alertModData.modName
            local latestAlert = alertModData.alerts[#alertModData.alerts]
            local alertTitle = latestAlert.title ~= "" and latestAlert.title
            local alertContents = latestAlert.contents
            local alertIcon = alertModData.icon
            local header = modName

            local subHeader = ""
            if alertModData.ts then
                subHeader = " (" .. formatDate(alertModData.ts) .. ")"
            elseif alertModID ~= "" then
                subHeader = " (" .. alertModID .. ")"
            end

            local modAuthor = alertModData.modAuthor
            local layout = self:determineLayout(alertModID, header, subHeader, alertTitle, alertContents, alertIcon)

            if layout.alertIcon then self:drawTextureScaled(layout.alertIcon, 4+(alertSystem.padding/3), layout.headerY, 32, 32, 1, 1, 1, 1) end

            local maxSubheaderX = math.min( ((alertSystem.padding*1.5)+layout.headerW), (self.width-layout.subHeaderW) )
            if subHeader then
                self:drawText(subHeader, maxSubheaderX, layout.headerY + (alertSystem.padding/5), 1, 1, 1, 0.7, UIFont.NewSmall)
            end

            self:drawText(layout.header, layout.headerX, layout.headerY, 1, 1, 1, 0.96, UIFont.NewMedium)

            local titleY = layout.headerY+layout.headerH+(alertSystem.padding/7)
            if alertTitle then
                self:drawText(alertTitle, layout.headerX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
            end

            if modAuthor then
                local authorX = self.alertContentPanel:getX()+self.alertContentPanel:getWidth()-(alertSystem.padding/4)
                self:drawTextRight(modAuthor, authorX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
            end

            self.alertContentPanel:setY((titleY+layout.titleH+(alertSystem.padding/7)))
            self.alertContentPanel:setHeight(self.alertContentPanel.originalH+(self.alertContentPanel.originalY-self.alertContentPanel:getY()))

            self.alertContentPanel:clampStencilRectToParent(0, 0, self.alertContentPanel:getWidth(), self.alertContentPanel:getHeight())
            self.alertContentPanel:setScrollHeight(layout.contentsH)
            self.alertContentPanel:drawText(layout.contents, self.padding/3, self.padding/3, 1, 1, 1, 0.8, UIFont.NewSmall)
            self.alertContentPanel:clearStencilRect()
        end
    end

    function alertSystem:render()
        ISPanelJoypad.render(self)

        if not self.collapsed then

            if alertSystem.spiffoTexture and (not self.collapsed) then
                local textureYOffset = self.height-(alertSystem.spiffoTexture:getHeight())
                self:drawTexture(alertSystem.spiffoTexture, self.width-(alertSystem.padding*1.7), textureYOffset, 1, 1, 1, 1)
            end

            if self.alertsLoaded and #self.alertsLoaded > 0 then
                local label = tostring(self.alertSelected).."/"..tostring(#self.alertsLoaded)
                self:drawText(label, 40, 7, 1, 1, 1, 0.7, UIFont.AutoNormSmall)
            end

            self:drawTexture(alertSystem.alertLeft, self.alertLeftX, 0, 0.7, 1, 1, 1)
            self:drawTexture(alertSystem.alertRight, self.alertRightX, 0, 0.7, 1, 1, 1)

            local alertBarX = (self.alertLeftX+32)

            local rectWidth = self.alertBarSpan-32
            self:drawRectBorder(alertBarX, 10, rectWidth, 12, 0.7, 1, 1, 1)

            if self.alertsLoaded and #self.alertsLoaded > 0 then
                local selectedAlertWidth = math.max(2, rectWidth/#self.alertsLoaded)
                self:drawRect(alertBarX+(selectedAlertWidth*(self.alertSelected-1)), 10, selectedAlertWidth, 12, 0.8, 1, 1, 1)
            end

        end

        if self.alertsLoaded and #self.alertsLoaded > 0 then
            local alertImage = (#self.alertsLoaded-(self.alertsOld or 0))>0 and alertSystem.alertTextureFull or alertSystem.alertTextureEmpty
            self:drawTexture(alertImage, 0, 0, 1, 1, 1, 1)
        end
    end

    local original_display = alertSystem.display
    function alertSystem.display(visible)
        original_display(visible)

        local instance = MainScreen.instance and MainScreen.instance.alertSystem

        if instance and not instance.__forcedCollapseInit then
            instance.collapsed = true; if instance.collapse then
                 instance.collapse.tooltip = getText("IGUI_ChuckAlertTooltip_Open")
                 instance:markCurrentAlertAsSeen()
            end
            instance:collapseApply(); instance.__forcedCollapseInit = true
        end
    end
end