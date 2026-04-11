require "ISUI/ISPanelJoypad"

require "ModManager/ModPresets/ModPresetsWindow"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

ModListPresets = ISPanelJoypad:derive("ModListPresets")

function ModListPresets:new(x, y, width, height, model)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o:noBackground()
    o.model = model
    o.childrenLine = {}
    o.childrenIndex = 1
    return o
end

function ModListPresets:createChildren()
    self.presetsButton = ISButton:new(0, 0, BUTTON_HGT, BUTTON_HGT, "", self, self.onPresetsButton)
    self.presetsButton.internal = "PRESETS"
    self.presetsButton:initialise()
    self.presetsButton:instantiate()
    self.presetsButton:setImage(getTexture("media/ui/ModManager/Presets.png"))
    self.presetsButton.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
    self:addChild(self.presetsButton)

    self.presetCombo = ISComboBox:new(self.presetsButton:getRight() + 5, 0, math.min(200, self.width/2.0), BUTTON_HGT, self, self.choosePreset)
    self.presetCombo:initialise()
    self.presetCombo:addOptionWithData(getText("UI_mods_preset_choose"), "default")
    self.presetCombo:addOptionWithData(getText("UI_mods_preset_disableAll"), "default")
    self.presetCombo:addOptionWithData(getText("UI_mods_preset_enableAll"), "default")
    self.presetCombo:setAnchorLeft(true);
    self.presetCombo:setAnchorRight(false);
    self.presetCombo:setAnchorTop(false);
    self.presetCombo:setAnchorBottom(true);
    self.presetCombo:ignoreWidthChange();
    self.presetCombo:ignoreHeightChange();
    self:addChild(self.presetCombo)

    self.savePresetButton = ISButton:new(0, 0, 100, BUTTON_HGT, getText("UI_btn_save"), self, self.onPresetButton);
    self.savePresetButton.internal = "SAVE";
    self.savePresetButton:initialise();
    self.savePresetButton:instantiate();
    self.savePresetButton:setAnchorLeft(true);
    self.savePresetButton:setAnchorRight(false);
    self.savePresetButton:setAnchorTop(false);
    self.savePresetButton:setAnchorBottom(true);
    self.savePresetButton.borderColor = {r=1, g=1, b=1, a=0.1};
    self.savePresetButton:setFont(UIFont.Small);
    self.savePresetButton:ignoreWidthChange();
    self.savePresetButton:ignoreHeightChange();
    self:addChild(self.savePresetButton);
    self.savePresetButton:setWidthToTitle()
    self.savePresetButton:setX(self.presetCombo:getRight() + UI_BORDER_SPACING)

    self.delPresetButton = ISButton:new(0, 0, 100, BUTTON_HGT, getText("UI_btn_del"), self, self.onPresetButton);
    self.delPresetButton.internal = "DELETE";
    self.delPresetButton:initialise();
    self.delPresetButton:instantiate();
    self.delPresetButton:setAnchorLeft(true);
    self.delPresetButton:setAnchorRight(false);
    self.delPresetButton:setAnchorTop(false);
    self.delPresetButton:setAnchorBottom(true);
    self.delPresetButton.borderColor = {r=1, g=1, b=1, a=0.1};
    self.delPresetButton:setFont(UIFont.Small);
    self.delPresetButton:ignoreWidthChange();
    self.delPresetButton:ignoreHeightChange();
    self:addChild(self.delPresetButton);
    self.delPresetButton:setWidthToTitle()
    self.delPresetButton:setX(self.savePresetButton:getRight() + UI_BORDER_SPACING)

    self.joypadIndexY = 1
    self.joypadIndex = 1
    self:insertNewLineOfButtons(self.presetsButton, self.presetCombo, self.savePresetButton, self.delPresetButton)
end

function ModListPresets:render()
    ISPanelJoypad.render(self)
    self:renderJoypadFocus()
end

function ModListPresets:addChild(child)
    ISPanelJoypad.addChild(self, child)
end

function ModListPresets:updateView()
    local temp = {}
    for i, option in ipairs(self.presetCombo.options) do
        if option.data == "default" then
            table.insert(temp, option)
        end
    end
    self.presetCombo.options = temp

    for name, data in pairs(self.parent.model.presets) do
        self.presetCombo:addOptionWithData(name, data)
    end
end

function ModListPresets:onPresetsButton(button)
    ModSelector.instance:setVisible(false)
    
    local width = 800
    local height = 600
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = (screenW - width) / 2
    local y = (screenH - height) / 2
    
    local selectedPresetName = nil
    local selectedOption = self.presetCombo.options[self.presetCombo.selected]
    if selectedOption and selectedOption.data ~= "default" then
        selectedPresetName = selectedOption.text
    end
    
    local window = ModPresetsWindow:new(x, y, width, height, self.model, self, selectedPresetName)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:bringToTop()
    window:setCapture(true)
    window.returnToUI = ModSelector.instance
    
    if self.joyfocus then
        window.prevFocus = self
        self.joyfocus.focus = window
        updateJoypadFocus(self.joyfocus)
    end
end

function ModListPresets:loadPreset(data, name)
    local modSet = {}
    for _, modID in ipairs(data) do
        modSet[modID] = true
    end

    local availableMods = {}
    for modId, modData in pairs(self.parent.model.mods) do
        if modSet[modId] then
            if not modData.isActive and modData.isAvailable then
                self.parent.model:forceActivateMods(modData.modInfo, true, true, true)
            end
            availableMods[modId] = true
        else
            if modData.isActive then
                self.parent.model:forceActivateMods(modData.modInfo, false, true, true)
            end
        end
    end
    self.parent.model:refreshMods()

    local modList = {}
    for _, id in ipairs(data) do
        if availableMods[id] then
            table.insert(modList, id)
        end
    end
    self.model:correctAndSaveModOrder(modList)

    self.presetCombo.selected = 1
    if name then
        for i, opt in ipairs(self.presetCombo.options) do
            if opt.text == name then
                self.presetCombo.selected = i
                break
            end
        end
    end

    local isMissedMods = false
    local data2 = {}
    for _, k in ipairs(data) do
        if availableMods[k] == nil then
            isMissedMods = true
            local t = luautils.split(k, "\\")
            data2[k] = t[1]
        end
    end

    if isMissedMods then
        ModSelector.instance:setVisible(false)

        local w = 600
        local h = 600
        self.missedModsPanel = ModSelector.MissedModsWindow:new(getCore():getScreenWidth()/2 - w/2, getCore():getScreenHeight() / 2 - h/2, w, h, data2)
        self.missedModsPanel:initialise();
        self.missedModsPanel:setAnchorRight(true);
        self.missedModsPanel:setAnchorLeft(true);
        self.missedModsPanel:setAnchorBottom(true);
        self.missedModsPanel:setAnchorTop(true);
        self.missedModsPanel:addToUIManager()
        self.missedModsPanel:bringToTop()
    end
end

function ModListPresets:onPresetButton(button)
    if button.internal == "SAVE" then
        local name = "New"
        if self.presetCombo.options[self.presetCombo.selected] and self.presetCombo.options[self.presetCombo.selected].data ~= "default" then
            name = self.presetCombo.options[self.presetCombo.selected].text or "New"
        end
        local modal = ISTextBox:new((getCore():getScreenWidth() / 2) - 140, (getCore():getScreenHeight() / 2) - 90, 280, 180, getText("UI_mods_SavePrompt"), name, self, self.onSavePreset);
        modal.backgroundColor.a = 0.9
        modal:initialise();
        modal:setAlwaysOnTop(true)
        modal:setCapture(true)
        modal:setValidateFunction(self, self.onValidateSavePreset)
        modal:addToUIManager()
        modal:bringToTop()
        if self.joyfocus then
            modal.prevFocus = self
            self.joyfocus.focus = modal
            updateJoypadFocus(self.joyfocus)
        end
    end
    if button.internal == "DELETE" then
        local name = self.presetCombo.options[self.presetCombo.selected].text
        self.parent.model.presets[name] = nil
        self.parent.model:saveModDataToFile()
        self:updateView()
        self.presetCombo.selected = 1
        self:choosePreset(self.presetCombo)
    end
    if button.internal == "SHARE" then
        if self.presetCombo.options[self.presetCombo.selected] and self.presetCombo.options[self.presetCombo.selected].data ~= "default" then
            local text = self.parent.model:getPresetShareText(self.presetCombo.options[self.presetCombo.selected].text)
            Clipboard.setClipboard(text)
            local modal = ISModalDialog:new(getCore():getScreenWidth()/2 - 280/2, getCore():getScreenHeight() / 2 - 180/2, 280, 180, "Mods preset text copied to clipboard", false)
            modal:initialise()
            modal:addToUIManager()
            if self.joyfocus then
                modal.prevFocus = self
                self.joyfocus.focus = modal
                updateJoypadFocus(self.joyfocus)
            end
        end
    end
    if button.internal == "ADD" then
        local modal = ISTextBox:new(getCore():getScreenWidth()/2 - 280/2, getCore():getScreenHeight() / 2 - 180/2, 280, 180, "Paste here mods preset text:", "", self, self.addSharedPreset)
        modal:initialise()
        modal:addToUIManager()
        if self.joyfocus then
            self.joyfocus.focus = modal
            updateJoypadFocus(self.joyfocus)
        end
    end
end

function ModListPresets:addSharedPreset(button)
    self.model:addSharedPreset(button)
    if button.parent.joyfocus then
        button.parent.joyfocus.focus = self
        updateJoypadFocus(button.parent.joyfocus)
    end
end

function ModListPresets:onValidateSavePreset(text)
    return SandboxOptions.isValidPresetName(text)
end

function ModListPresets:onSavePreset(button)
    local modal = button.parent;
    if button.internal == "OK" then
        local name = button.parent.entry:getText()
        if SandboxOptions.isValidPresetName(name) then
            modal:destroy()
            local data = {}
            local modArray = self.model:getActiveMods():getMods()
            for i = 0, modArray:size()-1 do
                local mId = modArray:get(i)
                table.insert(data, mId)
            end
            self.parent.model.presets[name] = data
            self.parent.model:saveModDataToFile()
            self:updateView()
            for i, opt in ipairs(self.presetCombo.options) do
                if opt.text == name then
                    self.presetCombo.selected = i
                end
            end
            self:choosePreset(self.presetCombo)
        else
            modal:showErrorMessage(true, getText("Sandbox_PresetName_Error"))
        end
    elseif button.internal == "CANCEL" then
        modal:destroy()
    end
    if button.parent.joyfocus then
        button.parent.joyfocus.focus = self
        updateJoypadFocus(button.parent.joyfocus)
    end
end

function ModListPresets:choosePreset(combo)
    local data = combo.options[combo.selected].data
    if data == "default" then
        self.delPresetButton:setEnable(false)
        if combo.selected == 2 then
            local ignored = {}; ignored["\\ModManager"] = true
            if self.parent.model.mods["\\ModManager"] then
                local req = self.parent.model.mods["\\ModManager"].modInfo:getRequire()
                if req then
                    for i=0, req:size()-1 do
                        ignored[req:get(i)] = true
                    end
                end
            end
            for _, modData in pairs(self.parent.model.mods) do
                if modData.isActive and not ignored[modData.modId] then
                    self.parent.model:forceActivateMods(modData.modInfo, false, true, true)
                end
            end
            self.parent.model:refreshMods()
        elseif combo.selected == 3 then
            for _, modData in pairs(self.parent.model.mods) do
                if not modData.isActive and modData.isAvailable and modData.modId ~= "ModTemplate" and not modData.isHidden then
                    self.parent.model:forceActivateMods(modData.modInfo, true, true, true)
                end
            end
            self.parent.model:refreshMods()
        end
        return
    end

    local presetSet = {}
    for _, modID in ipairs(data) do
        presetSet[modID] = true
    end

    local availableMods = {}
    self.delPresetButton:setEnable(true)
    for modId, modData in pairs(self.parent.model.mods) do
        if presetSet[modId] then
            if not modData.isActive and modData.isAvailable then
                self.parent.model:forceActivateMods(modData.modInfo, true, true, true)
            end
            availableMods[modId] = true
        else
            if modData.isActive then
                self.parent.model:forceActivateMods(modData.modInfo, false, true, true)
            end
        end
    end
    self.parent.model:refreshMods()

    local modList = {}
    for _, id in ipairs(data) do
        if availableMods[id] then
            table.insert(modList, id)
        end
    end
    self.model:correctAndSaveModOrder(modList)

    local isMissedMods = false
    local data2 = {}
    for _, k in ipairs(data) do
        if availableMods[k] == nil then
            isMissedMods = true
            local t = luautils.split(k, "\\")
            data2[k] = t[1]
        end
    end

    if isMissedMods then
        ModSelector.instance:setVisible(false)

        local w = 600
        local h = 600
        self.missedModsPanel = ModSelector.MissedModsWindow:new(getCore():getScreenWidth()/2 - w/2, getCore():getScreenHeight() / 2 - h/2, w, h, data2)
        self.missedModsPanel:initialise();
        self.missedModsPanel:setAnchorRight(true);
        self.missedModsPanel:setAnchorLeft(true);
        self.missedModsPanel:setAnchorBottom(true);
        self.missedModsPanel:setAnchorTop(true);
        self.missedModsPanel:addToUIManager()
        self.missedModsPanel:bringToTop()
    end
end

function ModListPresets:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self:restoreJoypadFocus(joypadData)
end

function ModListPresets:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
	self:clearJoypadFocus(joypadData)
end

function ModListPresets:onJoypadDown(button, joypadData)
    if button == Joypad.BButton and not self:isFocusOnControl() then
        joypadData.focus = self.parent
        updateJoypadFocus(joypadData)
        return
    end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end