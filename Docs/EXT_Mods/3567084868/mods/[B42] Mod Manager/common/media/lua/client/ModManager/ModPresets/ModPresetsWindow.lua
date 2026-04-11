require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "ISUI/ISToolTip"
require "ISUI/ISTabPanel"
require "ISUI/ISTextEntryBox"

require "ModManager/ModPresets/ModPresetsShare"

ModPresetsWindow = ISPanelJoypad:derive("ModPresetsWindow")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local BUTTON_HGT, UI_BORDER_SPACING = FONT_HGT_SMALL + 6, 10
local ICON_SIZE = 10

function ModPresetsWindow:createChildren()
    local listWidth = self.width / 3 - UI_BORDER_SPACING * 2
    local tabsHeight = self.height - (UI_BORDER_SPACING * 3 + BUTTON_HGT)
    local tabsY = UI_BORDER_SPACING * 3 + FONT_HGT_MEDIUM
    
    self.tabs = ISTabPanel:new(UI_BORDER_SPACING + 1, tabsY - 4, listWidth, tabsHeight - (tabsY - (UI_BORDER_SPACING + 1)) + 4)
    self.tabs:initialise()
    self.tabs.tabHeight = BUTTON_HGT + 1
    self.tabs:setAnchorLeft(true)
    self.tabs:setAnchorRight(false)
    self.tabs:setAnchorTop(true)
    self.tabs:setAnchorBottom(true)
    self.tabs:setEqualTabWidth(true)
    self.tabs:setCenterTabs(false)
    self.tabs.onActivateView = self.onTabActivated
    self.tabs.target = self
    self.tabs.borderColor = {r=0, g=0, b=0, a=0}
    
    self:addChild(self.tabs)

    self.presetsList = ISScrollingListBox:new(0, 0, self.tabs.width, self.tabs.height - self.tabs.tabHeight - 4)
    self.presetsList:initialise()
    self.presetsList:instantiate()
    self.presetsList:setAnchorLeft(true)
    self.presetsList:setAnchorRight(true)
    self.presetsList:setAnchorTop(true)
    self.presetsList:setAnchorBottom(true)
    self.presetsList.itemheight = FONT_HGT_MEDIUM + 6
    self.presetsList.doDrawItem = self.drawPresetItem
    self.presetsList:setOnMouseDownFunction(self, self.onSelectPreset)
    self.presetsList.drawBorder = true
    self.presetsList.parent = self
    self.presetsList.deletePresetTexture = getTexture("media/ui/ModManager/Trash.png")
    
    self.presetsList.onMouseDown = function(list, x, y)
        if self:onPresetListMouseDown(list, x, y) then return end
        ISScrollingListBox.onMouseDown(list, x, y)
    end

    self.presetsList.onMouseMove = function(list, dx, dy)
        ISScrollingListBox.onMouseMove(list, dx, dy)
        local row = list:rowAt(list:getMouseX(), list:getMouseY())
        local showTooltip = false
        if row ~= -1 then
            local iconX = 10
            local mx = list:getMouseX()
            if mx >= iconX and mx <= iconX + 16 then
                showTooltip = true
            end
        end
        
        if showTooltip then
            if not self.tooltipUI then
                self.tooltipUI = ISToolTip:new()
                self.tooltipUI:setOwner(self)
                self.tooltipUI:setVisible(false)
                self.tooltipUI:setAlwaysOnTop(true)
            end
            if not self.tooltipUI:getIsVisible() then
                self.tooltipUI:addToUIManager()
                self.tooltipUI:setVisible(true)
            end
            self.tooltipUI.description = getText("UI_btn_delete")
            self.tooltipUI:setDesiredPosition(getMouseX() + 10, getMouseY() - 35)
        else
            if self.tooltipUI and self.tooltipUI:getIsVisible() then
                self.tooltipUI:setVisible(false)
                self.tooltipUI:removeFromUIManager()
            end
        end
    end

    self.presetsList.onMouseMoveOutside = function(list, dx, dy)
        ISScrollingListBox.onMouseMoveOutside(list, dx, dy)
        if self.tooltipUI and self.tooltipUI:getIsVisible() then
            self.tooltipUI:setVisible(false)
            self.tooltipUI:removeFromUIManager()
        end
    end

    self.historyPanel = ISPanelJoypad:new(0, 0, self.tabs.width, self.tabs.height - self.tabs.tabHeight - 4)
    self.historyPanel:noBackground()
    self.historyPanel:initialise()
    self.historyPanel:instantiate()
    self.historyPanel:setAnchorLeft(true)
    self.historyPanel:setAnchorRight(true)
    self.historyPanel:setAnchorTop(true)
    self.historyPanel:setAnchorBottom(true)

    self.historyList = ISScrollingListBox:new(0, 0, self.historyPanel.width, self.historyPanel.height - BUTTON_HGT - UI_BORDER_SPACING)
    self.historyList:initialise()
    self.historyList:instantiate()
    self.historyList:setAnchorLeft(true)
    self.historyList:setAnchorRight(true)
    self.historyList:setAnchorTop(true)
    self.historyList:setAnchorBottom(true)
    self.historyList.itemheight = FONT_HGT_MEDIUM + 6
    self.historyList.doDrawItem = self.drawHistoryItem
    self.historyList:setOnMouseDownFunction(self, self.onSelectPreset)
    self.historyList.drawBorder = true
    self.historyList.parent = self
    self.historyList.deletePresetTexture = getTexture("media/ui/ModManager/Trash.png")

    self.historyList.onMouseDown = function(list, x, y)
        if self:onPresetListMouseDown(list, x, y) then return end
        ISScrollingListBox.onMouseDown(list, x, y)
    end
    
    self.historyList.onMouseMove = self.presetsList.onMouseMove
    self.historyList.onMouseMoveOutside = self.presetsList.onMouseMoveOutside

    self.deleteAllHistoryBtn = ISButton:new(0, self.historyList:getBottom() + UI_BORDER_SPACING, self.historyPanel.width, BUTTON_HGT, getText("UI_btn_deleteAll"), self, self.onDeleteAllHistory)
    self.deleteAllHistoryBtn:initialise()
    self.deleteAllHistoryBtn:instantiate()
    self.deleteAllHistoryBtn:setAnchorLeft(true)
    self.deleteAllHistoryBtn:setAnchorRight(true)
    self.deleteAllHistoryBtn:setAnchorTop(false)
    self.deleteAllHistoryBtn:setAnchorBottom(true)
    self.deleteAllHistoryBtn.borderColor = {r=1, g=1, b=1, a=0.4}
    self.deleteAllHistoryBtn:setEnable(false)

    self.historyPanel:addChild(self.historyList)
    self.historyPanel:addChild(self.deleteAllHistoryBtn)
    
    self.historyPanel.joypadIndexY = 1
    self.historyPanel.joypadIndex = 1
    self.historyPanel:insertNewLineOfButtons(self.historyList)
    self.historyPanel:insertNewLineOfButtons(self.deleteAllHistoryBtn)

    self.tabs:addView(getText("UI_modpresets_presetsTab"), self.presetsList)
    self.tabs:addView(getText("UI_modpresets_historyTab"), self.historyPanel)

    self.presetsList:setY(self.tabs.tabHeight + 4)
    self.historyPanel:setY(self.tabs.tabHeight + 4)

    self.tabs.maxLength = (self.tabs.width - 2) / 2 - 1

    self.modsList = ISScrollingListBox:new(self.tabs:getRight() + UI_BORDER_SPACING, self.tabs.y + self.tabs.tabHeight + 4, self.width - self.tabs:getRight() - UI_BORDER_SPACING * 2 - 1, self.presetsList.height)
    self.modsList:initialise()
    self.modsList:instantiate()
    self.modsList:setAnchorLeft(true)
    self.modsList:setAnchorRight(true)
    self.modsList:setAnchorTop(true)
    self.modsList:setAnchorBottom(true)
    self.modsList.itemheight = BUTTON_HGT
    self.modsList.doDrawItem = self.drawModItem
    self.modsList.drawBorder = true
    self.modsList.deleteModTexture = getTexture("media/ui/ModManager/Close.png")
    self.modsList.onMouseDown = function(list, x, y)
        if self:onModListMouseDown(list, x, y) then return end
        ISScrollingListBox.onMouseDown(list, x, y)
    end
    self.modsList.onMouseMove = function(list, dx, dy)
        ISScrollingListBox.onMouseMove(list, dx, dy)
        self:onModListMouseMove(list)
    end
    self.modsList.onMouseMoveOutside = function(list, dx, dy)
        ISScrollingListBox.onMouseMoveOutside(list, dx, dy)
        self.hoveredDeleteRow = -1
    end
    self.modsList.prerender = function(list)
        ISScrollingListBox.prerender(list)
        if list.vscroll then
            list.vscroll:setVisible(list:isVScrollBarVisible())
        end
    end
    self:addChild(self.modsList)

    local searchX = self.modsList.x
    local searchW = self.modsList.width
    local searchY = self.modsList.y - BUTTON_HGT - 5
    
    self.searchEntry = ISTextEntryBox:new("", searchX, searchY, searchW, BUTTON_HGT)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry.onTextChange = function()
        if self.selectedPresetData then
            self:fillMods(self.selectedPresetData)
        end
    end
    self.searchEntry:setClearButton(true)
    self:addChild(self.searchEntry)
    
    local btnGap = UI_BORDER_SPACING
    
    local splitBtnWidth = (listWidth - (2 - 1) * btnGap) / 2

    self.backButton = ISButton:new(UI_BORDER_SPACING + 1, self.height - UI_BORDER_SPACING - BUTTON_HGT, splitBtnWidth, BUTTON_HGT, getText("UI_btn_back"), self, self.onOptionMouseDown)
    self.backButton.internal = "BACK"
    self.backButton:initialise()
    self.backButton:instantiate()
    self.backButton:setAnchorLeft(true)
    self.backButton:setAnchorRight(false)
    self.backButton:setAnchorTop(false)
    self.backButton:setAnchorBottom(true)
    self.backButton:enableCancelColor()
    self:addChild(self.backButton)

    self.addPresetButton = ISButton:new(self.backButton:getRight() + btnGap, self.height - UI_BORDER_SPACING - BUTTON_HGT, splitBtnWidth, BUTTON_HGT, getText("UI_btn_add"), self, self.onOptionMouseDown)
    self.addPresetButton.internal = "ADD"
    self.addPresetButton:initialise()
    self.addPresetButton:instantiate()
    self.addPresetButton:setAnchorLeft(true)
    self.addPresetButton:setAnchorRight(false)
    self.addPresetButton:setAnchorTop(false)
    self.addPresetButton:setAnchorBottom(true)
    self.addPresetButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.addPresetButton)

    self.exportButton = ISButton:new(self.addPresetButton:getRight() + btnGap, self.height - UI_BORDER_SPACING - BUTTON_HGT, 100, BUTTON_HGT, getText("UI_btn_share"), self, self.onOptionMouseDown)
    self.exportButton.internal = "EXPORT"
    self.exportButton:initialise()
    self.exportButton:instantiate()
    self.exportButton:setAnchorLeft(true)
    self.exportButton:setAnchorRight(false)
    self.exportButton:setAnchorTop(false)
    self.exportButton:setAnchorBottom(true)
    self.exportButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self.exportButton:setEnable(false)
    self:addChild(self.exportButton)

    self.acceptButton = ISButton:new(self.width - UI_BORDER_SPACING - 100, self.height - UI_BORDER_SPACING - BUTTON_HGT, 100, BUTTON_HGT, getText("UI_btn_select"), self, self.onOptionMouseDown)
    self.acceptButton.internal = "ACCEPT"
    self.acceptButton:initialise()
    self.acceptButton:instantiate()
    self.acceptButton:setAnchorLeft(false)
    self.acceptButton:setAnchorRight(true)
    self.acceptButton:setAnchorTop(false)
    self.acceptButton:setAnchorBottom(true)
    self.acceptButton:enableAcceptColor()
    self.acceptButton:setEnable(false)
    self:addChild(self.acceptButton)

    local modOrderBtnWidth = getTextManager():MeasureStringX(UIFont.Small, getText("UI_mods_ModsOrder")) + 20
    self.modOrderBtn = ISButton:new(self.acceptButton:getX() - modOrderBtnWidth - UI_BORDER_SPACING, self.height - UI_BORDER_SPACING - BUTTON_HGT, modOrderBtnWidth, BUTTON_HGT, getText("UI_mods_ModsOrder"), self, self.onOptionMouseDown)
    self.modOrderBtn.internal = "MODSORDER"
    self.modOrderBtn:initialise()
    self.modOrderBtn:instantiate()
    self.modOrderBtn:setAnchorLeft(false)
    self.modOrderBtn:setAnchorRight(true)
    self.modOrderBtn:setAnchorTop(false)
    self.modOrderBtn:setAnchorBottom(true)
    self.modOrderBtn.borderColor = {r=1, g=1, b=1, a=0.1}
    self.modOrderBtn:setEnable(false)
    self:addChild(self.modOrderBtn)

    self:fillPresets()

    if self.initialPresetName then
        for i, item in ipairs(self.presetsList.items) do
            if item.text == self.initialPresetName then
                self.presetsList.selected = i
                self:onSelectPreset(item.item)
                return
            end
        end
    end

    if self.presetsList.items and #self.presetsList.items > 0 then
        self.presetsList.selected = 1; self:onSelectPreset(self.presetsList.items[1].item)
    end
end

function ModPresetsWindow:onModListMouseMove(list)
    self.hoveredDeleteRow = -1
    local mx = list:getMouseX()
    local my = list:getMouseY()
    local row = list:rowAt(mx, my)
    if row == -1 then return end

    local scrollBarWid = (list:isVScrollBarVisible() and list.vscroll and list.vscroll:getWidth() or 0)
    local margin = scrollBarWid > 0 and 2 or 8
    local iconX = list:getWidth() - margin - ICON_SIZE - scrollBarWid

    if mx >= iconX and mx <= iconX + ICON_SIZE then
        self.hoveredDeleteRow = row
    end
end

function ModPresetsWindow:updateDeleteAllButtonText()
    if self.deleteAllHistoryBtn then
        local count = self.historyList.items and #self.historyList.items or 0
        if count > 0 then
            self.deleteAllHistoryBtn:setTitle(getText("UI_btn_deleteAll") .. " (" .. count .. "/30)")
        else
            self.deleteAllHistoryBtn:setTitle(getText("UI_btn_deleteAll"))
        end
    end
end

function ModPresetsWindow:onDeleteAllHistory(button)
    local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 175, getCore():getScreenHeight() / 2 - 75, 350, 150, getText("UI_modpresets_deleteAll_dialog"), true, self, self.onConfirmDeleteAllHistory)
    modal:initialise()
    modal:addToUIManager()
    modal:bringToTop()
    modal.yes:enableCancelColor()
    modal.no.backgroundColor = {r=0, g=0, b=0, a=1}
    modal.no.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
    modal.no.backgroundColorMouseOver = {r=0.3, g=0.3, b=0.3, a=1}
    if self.joyfocus then
        modal.prevFocus = self.historyPanel
        self.joyfocus.focus = modal
        updateJoypadFocus(self.joyfocus)
    end
end

function ModPresetsWindow:onConfirmDeleteAllHistory(button)
    if button.internal == "YES" then
        local writer = getFileWriter("ModManager/HistoryData.cfg", true, false)
        if writer then
            writer:close()
        end
        self:fillHistory()
        self.modsList:clear()
        self.acceptButton:setEnable(false)
        self.exportButton:setEnable(false)
        self.modOrderBtn:setEnable(false)
        self.selectedPresetData = nil
    end
end

function ModPresetsWindow:onTabActivated()
    self.modsList:clear()
    self.acceptButton:setEnable(false)
    self.exportButton:setEnable(false)
    self.modOrderBtn:setEnable(false)
    self.selectedPresetData = nil
    self.selectedPresetName = nil
    
    if self.searchEntry then
        self.searchEntry:setText("")
    end

    local activeView = self.tabs:getActiveView()
    
    if activeView == self.presetsList then
        self.addPresetButton:setEnable(true)
        self:fillPresets()
    elseif activeView == self.historyPanel then
        self.addPresetButton:setEnable(false)
        self:fillHistory()
    end
    
    if activeView == self.historyPanel and self.historyList.items and #self.historyList.items > 0 then
        self.historyList.selected = 1; self:onSelectPreset(self.historyList.items[1].item)
    elseif activeView == self.presetsList and activeView.items and #activeView.items > 0 then
        activeView.selected = 1; self:onSelectPreset(activeView.items[1].item)
    end
end

function ModPresetsWindow:onPresetListMouseDown(list, x, y)
    local row = list:rowAt(x, y)
    if row == -1 then return false end
    
    local iconX = 10
    if x >= iconX and x <= iconX + 16 then
        local presetName = list.items[row].text
        
        local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 175, getCore():getScreenHeight() / 2 - 75, 350, 150, getText("UI_btn_del") .. ": " .. presetName .. "?", true, self, self.onConfirmDeletePreset)
        modal:initialise()
        modal:addToUIManager()
        modal:bringToTop()
        modal.presetName = presetName
        modal.isHistory = (list == self.historyList)
        
        modal.yes:enableCancelColor()
        modal.no.backgroundColor = {r=0, g=0, b=0, a=1}
        modal.no.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
        modal.no.backgroundColorMouseOver = {r=0.3, g=0.3, b=0.3, a=1}
        
        return true
    end
    return false
end

function ModPresetsWindow:onModListMouseDown(list, x, y)
    local row = list:rowAt(x, y)
    if row == -1 then return false end
    
    local scrollBarWid = (list:isVScrollBarVisible() and list.vscroll and list.vscroll:getWidth() or 0)
    local margin = scrollBarWid > 0 and 2 or 8
    
    local iconX = list:getWidth() - margin - ICON_SIZE - scrollBarWid
    if x >= iconX and x <= iconX + ICON_SIZE then
        local item = list.items[row]
        self:removeModFromPreset(item.item)
        return true
    end
    return false
end

function ModPresetsWindow:removeModFromPreset(modID)
    if not self.selectedPresetData then return end
    
    local index = -1
    for i, v in ipairs(self.selectedPresetData) do
        if v == modID then index = i; break end
    end
    
    if index ~= -1 then
        table.remove(self.selectedPresetData, index)
    end
    
    if #self.selectedPresetData == 0 then
        if self.selectedPresetName then
            self.model.presets[self.selectedPresetName] = nil
            self.model:saveModDataToFile()
        end
        
        self:fillPresets()
        
        if self.parent and self.parent.updateView then
            self.parent:updateView()
        end
        
        self.modsList:clear()
        self.acceptButton:setEnable(false)
        self.exportButton:setEnable(false)
        self.modOrderBtn:setEnable(false)
        self.selectedPresetData = nil
        self.selectedPresetName = nil
        
        if self.presetsList.items and #self.presetsList.items > 0 then
            self.presetsList.selected = 1
            self:onSelectPreset(self.presetsList.items[1].item)
        end
        return
    end
    
    if self.selectedPresetName and self.model.presets[self.selectedPresetName] then
        self.model.presets[self.selectedPresetName] = self.selectedPresetData
        self.model:saveModDataToFile()
    end
    
    self:fillMods(self.selectedPresetData)
    self:onModListMouseMove(self.modsList)
end

function ModPresetsWindow:onConfirmDeletePreset(button)
    if button.internal == "YES" then
        local presetName = button.parent.presetName
        if button.parent.isHistory then
            local file = getFileReader("ModManager/HistoryData.cfg", false)
            local lines = {}
            if file then
                local line = file:readLine()
                while line ~= nil do
                    if not luautils.stringStarts(line, presetName .. ":") then
                        table.insert(lines, line)
                    end
                    line = file:readLine()
                end
                file:close()
            end
            
            local writer = getFileWriter("ModManager/HistoryData.cfg", true, false)
            if writer then
                for _, line in ipairs(lines) do
                    writer:write(line .. "\r\n")
                end
                writer:close()
            end
            
            self:fillHistory()
        else
            self.model.presets[presetName] = nil
            self.model:saveModDataToFile()
            self:fillPresets()
            
            if self.parent and self.parent.updateView and self.parent.presetCombo then
                local combo = self.parent.presetCombo
                local currentText = combo.options[combo.selected] and combo.options[combo.selected].text
                
                self.parent:updateView()
                
                local found = false
                for i, opt in ipairs(combo.options) do
                    if opt.text == currentText then
                        combo.selected = i
                        found = true
                        break
                    end
                end
                
                if not found then
                    combo.selected = 1
                end
            end
        end

        local activeView = self.tabs:getActiveView()
        local list = activeView
        if activeView == self.historyPanel then list = self.historyList end

        list:onMouseMove(0, 0)

        if list.items and #list.items > 0 then
            list.selected = 1
            self:onSelectPreset(list.items[1].item)
        else
            self.modsList:clear()
            self.acceptButton:setEnable(false)
            self.exportButton:setEnable(false)
            self.modOrderBtn:setEnable(false)
            self.selectedPresetData = nil
        end
    end
end

function ModPresetsWindow:fillPresets()
    self.presetsList:clear()
    local presets = self.model.presets
    for name, data in pairs(presets) do
        self.presetsList:addItem(name, data)
    end
    self.presetsList:sort()
end

function ModPresetsWindow:fillHistory()
    self.historyList:clear()
    local file = getFileReader("ModManager/HistoryData.cfg", false)
    if not file then
        if self.deleteAllHistoryBtn then
            self.deleteAllHistoryBtn:setEnable(false)
            self:updateDeleteAllButtonText()
        end
        return
    end
    local historyData = {}
    local line = file:readLine()
    while line ~= nil do
        local sepIndex = string.find(line, ":")
        if sepIndex ~= nil then
            local presetName = string.sub(line, 0, sepIndex - 1)
            local modsString = string.sub(line, sepIndex + 1)
            local data = {}
            for i, val in ipairs(luautils.split(modsString, ";")) do
                table.insert(data, val)
            end
            table.insert(historyData, {name=presetName, data=data})
        end
        line = file:readLine()
    end
    file:close()

    table.sort(historyData, function(a, b) return a.name > b.name end)

    for i, item in ipairs(historyData) do
        self.historyList:addItem(item.name, item.data)
    end

    if self.deleteAllHistoryBtn then
        self.deleteAllHistoryBtn:setEnable(#self.historyList.items > 0)
        self:updateDeleteAllButtonText()
    end
end

function ModPresetsWindow:drawPresetItem(y, item, alt)
    local isMouseOver = self.mouseoverselected == item.index
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    elseif isMouseOver then
        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 2, 0.95, 0.05, 0.05, 0.05)
    end

    local textX = 10
    if isMouseOver then
        local iconY = y + (item.height - 16) / 2
        self:drawTexture(self.deletePresetTexture, textX, iconY, 1, 1, 1, 1)
        textX = textX + 16 + 6
    end

    self:drawText(item.text, textX, y + (item.height - FONT_HGT_MEDIUM) / 2, 0.9, 0.9, 0.9, 0.9, UIFont.Medium)
    
    return y + item.height
end

function ModPresetsWindow:drawHistoryItem(y, item, alt)
    local isMouseOver = self.mouseoverselected == item.index
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    elseif isMouseOver then
        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 2, 0.95, 0.05, 0.05, 0.05)
    end
    
    local textX = 10
    if isMouseOver then
        local iconY = y + (item.height - 16) / 2
        self:drawTexture(self.deletePresetTexture, textX, iconY, 1, 1, 1, 1)
        textX = textX + 16 + 6
    end

    self:drawText(item.text, textX, y + (item.height - FONT_HGT_MEDIUM) / 2, 0.9, 0.9, 0.9, 0.9, UIFont.Medium)
    
    return y + item.height
end

function ModPresetsWindow:onSelectPreset(item)
    if self.searchEntry then
        self.searchEntry:setText("")
    end
    
    if self.tabs:getActiveView() == self.presetsList and self.presetsList.selected > 0 then
        self.selectedPresetName = self.presetsList.items[self.presetsList.selected].text
    elseif self.tabs:getActiveView() == self.historyPanel and self.historyList.selected > 0 then
        self.selectedPresetName = self.historyList.items[self.historyList.selected].text
    end
    self.selectedPresetData = item
    self.acceptButton:setEnable(true)
    self.exportButton:setEnable(true)
    
    if self.tabs:getActiveView() == self.historyPanel then
        self.modOrderBtn:setEnable(false)
    else
        self.modOrderBtn:setEnable(true)
    end
    
    self:fillMods(item)
end

function ModPresetsWindow:fillMods(data)
    self.modsList:clear()
    local search = self.searchEntry and self.searchEntry:getInternalText() or ""
    search = string.lower(search)
    
    for i, modID in ipairs(data) do
        local modInfo = getModInfoByID(modID)
        local name = modID
        local available = false
        if modInfo then
            name = modInfo:getName()
            available = true
        end
        
        if search == "" or string.find(string.lower(name), search, 1, true) or string.find(string.lower(modID), search, 1, true) then
            local item = self.modsList:addItem(name, modID)
            item.available = available
        end
    end
end

function ModPresetsWindow:drawModItem(y, item, alt)
    local isMouseOver = self.mouseoverselected == item.index
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    end

    local r, g, b = 0.9, 0.9, 0.9
    if not item.available then
        r, g, b = 1.0, 0.2, 0.2
    end

    local textAlpha = 0.9
    if self.parent.hoveredDeleteRow and self.parent.hoveredDeleteRow ~= -1 and self.parent.hoveredDeleteRow ~= item.index then
        textAlpha = 0.5
    end

    self:drawText(item.text, 10, y + (item.height - FONT_HGT_SMALL) / 2, r, g, b, textAlpha, UIFont.Small)
    
    if isMouseOver then
        local scrollBarWid = (self:isVScrollBarVisible() and self.vscroll and self.vscroll:getWidth() or 0)
        local margin = scrollBarWid > 0 and 2 or 8

        local x = self:getWidth() - margin - ICON_SIZE - scrollBarWid
        local yIcon = y + (item.height - ICON_SIZE) / 2
        local alpha = 0.5
        local mx = self:getMouseX()
        local my = self:getMouseY()
        if mx >= x and mx <= x + ICON_SIZE and my >= yIcon and my <= yIcon + ICON_SIZE then
            alpha = 1.0
        end
        self:drawTextureScaled(self.deleteModTexture, x, yIcon, ICON_SIZE, ICON_SIZE, alpha, 1, 1, 1)
    end
    
    return y + item.height
end

function ModPresetsWindow:onOptionMouseDown(button)
    if button.internal == "BACK" then
        self:setVisible(false)
        self:removeFromUIManager()
        if self.returnToUI then
            self.returnToUI:setVisible(true)
        end
    elseif button.internal == "ACCEPT" then
        if self.selectedPresetData then
            self.parent:loadPreset(self.selectedPresetData, self.selectedPresetName)
            self:setVisible(false)
            self:removeFromUIManager()
            if self.returnToUI then
                self.returnToUI:setVisible(true)
            end
        end
    elseif button.internal == "ADD" then
        local modal = ISTextBox:new(getCore():getScreenWidth()/2 - 280/2, getCore():getScreenHeight() / 2 - 180/2, 280, 180, "Paste here mods preset text:", "", self, self.onAddSharedPreset)
        modal:initialise()
        modal:addToUIManager()
        modal:bringToTop()
        modal:setCapture(true)
        if self.joyfocus then
            self.joyfocus.focus = modal
            updateJoypadFocus(self.joyfocus)
        end
    elseif button.internal == "EXPORT" then
        if self.selectedPresetData and self.selectedPresetName then
            local width = 500
            local height = 400
            local screenW = getCore():getScreenWidth()
            local screenH = getCore():getScreenHeight()
            local x = (screenW - width) / 2
            local y = (screenH - height) / 2
            
            local window = ModPresetsShare:new(x, y, width, height, self.model, self.selectedPresetName, self.selectedPresetData)
            window:initialise()
            window:instantiate()
            window:addToUIManager()
            window:bringToTop()
            window:setCapture(true)
            window.returnToUI = self
            self.exportWindow = window
        end
    elseif button.internal == "MODSORDER" then
        if self.selectedPresetData then
            self:openSorter()
        end
    end
end

function ModPresetsWindow:openSorter()
    self:setVisible(false)
    local width = self.width
    local height = self.height
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = (screenW - width) / 2
    local y = (screenH - height) / 2

    local panel = ModSelector.ModLoadOrderPanel:new(x, y, width, height, self.model)
    panel:initialise()
    panel:instantiate()
    
    panel.modList:clear()
    
    for _, modID in ipairs(self.selectedPresetData) do
        local modInfo = getModInfoByID(modID)
        if modInfo then
            local modData = {}
            modData.name = modInfo:getName()
            modData.icon = modInfo:getIcon()
            modData.modId = modInfo:getId()
            modData.modInfo = modInfo
            local item = panel.modList:addItem("", modData)
            item.color = {r = 0.9, g = 0.9, b = 0.9}
            item.tooltip = panel:getTooltip(modData.modInfo)
        end
    end
    panel.modList:updateModsColor()

    local onOptionMouseDownOverride = function(this, button, x, y)
        if button.internal == "ACCEPT" then
            local data = {}
            for i, val in ipairs(this.modList.items) do
                table.insert(data, val.item.modId)
            end
            
            self.model.presets[self.selectedPresetName] = data
            self.model:saveModDataToFile()
            self:fillPresets()
            
            for i, item in ipairs(self.presetsList.items) do
                if item.text == self.selectedPresetName then
                    self.presetsList.selected = i
                    self:onSelectPreset(item.item)
                    break
                end
            end
        elseif button.internal == "AUTO" then
            if this.autoSort then 
                this:autoSort()
                this.modList:updateModsColor()
            end
            return
        end
        this:setVisible(false)
        this:removeFromUIManager()
        self:setVisible(true)
    end
    
    panel.acceptButton:setOnClick(onOptionMouseDownOverride, panel)
    panel.backButton:setOnClick(onOptionMouseDownOverride, panel)
    if panel.autoButton then
        panel.autoButton:setOnClick(onOptionMouseDownOverride, panel)
    end

    panel:addToUIManager()
    panel:bringToTop()
    if self.joyfocus then
        panel.prevFocus = self
        self.joyfocus.focus = panel
        updateJoypadFocus(self.joyfocus)
    end
end

function ModPresetsWindow:onAddSharedPreset(button)
    if button.internal == "OK" then
        local line = button.parent.entry:getText()
        local presetName, modsString = line:match('^([^:]+):(.*)$')
        
        if presetName and modsString then
            presetName = presetName:gsub("^%s*(.-)%s*$", "%1")

            self.model.presets[presetName] = {}
            for modId in modsString:gmatch("([^;]+)") do
                if modId ~= "" then
                    table.insert(self.model.presets[presetName], modId)
                end
            end
            
            self.model:saveModDataToFile()
            self:fillPresets()
            if self.parent and self.parent.updateView then
                self.parent:updateView()
            end
            
            for i, item in ipairs(self.presetsList.items) do
                if item.text == presetName then
                    self.presetsList.selected = i
                    self:onSelectPreset(item.item)
                    self.presetsList:ensureVisible(i)
                    break
                end
            end
        end
    end
    button.parent:destroy()
    if button.parent.joyfocus then
        button.parent.joyfocus.focus = self
        updateJoypadFocus(button.parent.joyfocus)
    end
end

function ModPresetsWindow:prerender()
    ISPanelJoypad.prerender(self); self:drawTextCentre(getText("UI_modpresets_title"), self.width / 2, UI_BORDER_SPACING + 1, 1, 1, 1, 1, UIFont.Medium)
end

function ModPresetsWindow:render()
    ISPanelJoypad.render(self)
    self:renderJoypadFocus()
    if self.exportWindow and self.exportWindow:isReallyVisible() then
        self:drawRect(0, 0, self.width, self.height, 0.5, 0, 0, 0)
    end
end

function ModPresetsWindow:new(x, y, width, height, model, parent, selectedPresetName)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=1, g=1, b=1, a=0.2}
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.model = model
    o.parent = parent
    o.initialPresetName = selectedPresetName
    return o
end