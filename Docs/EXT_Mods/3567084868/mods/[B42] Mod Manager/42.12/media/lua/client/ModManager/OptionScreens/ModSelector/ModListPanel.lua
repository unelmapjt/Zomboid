require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModSelector"
require "OptionScreens/ModSelector/ModListPanel"

local ModListPanel = ModSelector.ModListPanel

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local LABEL_HGT = FONT_HGT_MEDIUM + 6
local UI_BORDER_SPACING = 10
local JOYPAD_TEX_SIZE = 32
local BUTTON_PADDING = JOYPAD_TEX_SIZE + UI_BORDER_SPACING*2

function ModListPanel:updateView()
    local selectedModId = nil
    if self.modList:getSelectedModData() then
        selectedModId = self.modList:getSelectedModData().modId
    end

    self:applyFilters()
    self.modList:clear()

    for _, modData in pairs(self.model.currentMods) do
        self.modList:addItem("", modData)
    end

    local newSelectedIndex = 1
    if selectedModId then
        for i, item in ipairs(self.modList.items) do
            if item.item.modId == selectedModId then
                newSelectedIndex = i
                break
            end
        end
    end
    self.modList.selected = newSelectedIndex
end

function ModListPanel:render()
    ISPanelJoypad.render(self)
    self:drawRectBorder(0, self.modOptionsButton:getBottom() + UI_BORDER_SPACING, self.width, self.height - self.modOptionsButton:getBottom() - UI_BORDER_SPACING, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.joyfocus and self.joypadListFocus then
        self:drawTextureScaled(Joypad.Texture.YButton, self.modOptionsButton.x - BUTTON_HGT - UI_BORDER_SPACING, self.modOptionsButton.y, JOYPAD_TEX_SIZE, JOYPAD_TEX_SIZE, 1, 1, 1, 1)
    end
end

function ModListPanel:drawCustomRectBorder(x, y, w, h, r, g, b, a)
    if self.javaObject ~= nil then
        self.javaObject:DrawTextureScaledColor(nil, x, y, 2, h, r, g, b, a);
        self.javaObject:DrawTextureScaledColor(nil, x+2, y, w-4, 2, r, g, b, a);
        self.javaObject:DrawTextureScaledColor(nil, x+w-2, y, 2, h, r, g, b, a);
        self.javaObject:DrawTextureScaledColor(nil, x+2, y+h-2, w-4, 2, r, g, b, a);
    end
end

function ModListPanel:prerender()
    ISPanelJoypad.prerender(self)
    self.modOptionsButton:setEnable(#PZAPI.ModOptions.Data > 0)
    if self.joypadFocused then
        self:drawCustomRectBorder(1, 1, self:getWidth()-2, self:getHeight()-2, 0.2, 1, 1, 0.4)
    end
end

function ModListPanel:createChildren()
    local label = ISLabel:new(UI_BORDER_SPACING+1, UI_BORDER_SPACING+1, LABEL_HGT, getText("UI_modselector_filter"), 1.0, 1.0, 1.0, 1.0, UIFont.Medium, true)
    self:addChild(label)

    self.filterCombo = ISComboBox:new(label:getRight() + UI_BORDER_SPACING, UI_BORDER_SPACING+1, math.min(200, self.width/2.0 - label:getRight()) * 0.55, BUTTON_HGT, self, self.updateView)
    self.filterCombo:initialise()
    for type, iconName in pairs(ModSelector.Model.categories) do
        self.filterCombo:addOption(getText(type))
    end
    self.filterCombo.selected = 1
    self:addChild(self.filterCombo)

    local sortLabel = ISLabel:new(self.filterCombo:getRight() + UI_BORDER_SPACING, UI_BORDER_SPACING+1, LABEL_HGT, getText("UI_modlistpanel_sortBy"), 1.0, 1.0, 1.0, 1.0, UIFont.Medium, true)
    self:addChild(sortLabel)
    self.sortLabel = sortLabel

    self.sortCombo = ISComboBox:new(sortLabel:getRight() + UI_BORDER_SPACING, UI_BORDER_SPACING+1, self.filterCombo:getWidth() * 1.75, BUTTON_HGT, self, self.onSortChanged)
    self.sortCombo:initialise()
    self.sortCombo:addOptionWithData(getText("UI_modlistpanel_sortBy_name"), "name")
    self.sortCombo:addOptionWithData(getText("UI_modlistpanel_sortBy_date"), "date_added")
    self.sortCombo:addOptionWithData(getText("UI_modlistpanel_sortBy_dateUpdated"), "date_updated")
    self.sortCombo.selected = 1
    self:addChild(self.sortCombo)

    label = ISLabel:new(0, UI_BORDER_SPACING+1, LABEL_HGT, getText("UI_sandbox_searchEntryBoxWord") .. ":", 1.0, 1.0, 1.0, 1.0, UIFont.Medium, true)
    self:addChild(label)
    self.searchLabel = label

    self.searchEntry = ISTextEntryBox:new("", 0, UI_BORDER_SPACING+1, (self.width - self.sortCombo:getRight() - UI_BORDER_SPACING * 3 - self.searchLabel:getWidth()), BUTTON_HGT)
    self.searchEntry:setX(self.width - UI_BORDER_SPACING - self.searchEntry:getWidth() - 1)
    self.searchLabel:setX(self.searchEntry:getX() - self.searchLabel:getWidth() - UI_BORDER_SPACING)

    self.searchEntry.font = UIFont.Small
    self.searchEntry.onTextChange = function() self:updateView() end
    self.searchEntry.setText = ModListPanel.setText
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setClearButton(true)
    self:addChild(self.searchEntry)

    local tickboxWidth = BUTTON_HGT + UI_BORDER_SPACING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_modselector_showEnabledMods"))
    self.enabledModsTickbox = ISTickBox:new(UI_BORDER_SPACING+1, self.filterCombo:getBottom() + UI_BORDER_SPACING, tickboxWidth, BUTTON_HGT, "", self, self.onEnabledModsTickbox);
    self.enabledModsTickbox:initialise();
    self.enabledModsTickbox:instantiate();
    self.enabledModsTickbox:addOption(getText("UI_modselector_showEnabledMods"));
    self:addChild(self.enabledModsTickbox);

    tickboxWidth = BUTTON_HGT + UI_BORDER_SPACING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_modselector_showDisabledMods"))
    self.disabledModsTickbox = ISTickBox:new(self.enabledModsTickbox:getRight() + UI_BORDER_SPACING, self.enabledModsTickbox.y, tickboxWidth, BUTTON_HGT, "", self, self.onDisabledModsTickbox);
    self.disabledModsTickbox:initialise();
    self.disabledModsTickbox:instantiate();
    self.disabledModsTickbox:addOption(getText("UI_modselector_showDisabledMods"));
    self:addChild(self.disabledModsTickbox);

    tickboxWidth = BUTTON_HGT + UI_BORDER_SPACING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_modselector_showHiddenMods"))
    self.hiddenModsTickbox = ISTickBox:new(self.disabledModsTickbox:getRight() + UI_BORDER_SPACING, self.disabledModsTickbox.y, tickboxWidth, BUTTON_HGT, "", self, self.updateView);
    self.hiddenModsTickbox:initialise();
    self.hiddenModsTickbox:instantiate();
    self.hiddenModsTickbox:addOption(getText("UI_modselector_showHiddenMods"));
    self:addChild(self.hiddenModsTickbox);

    local btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_modselector_modOptions"))
    self.modOptionsButton = ISButton:new(self.width - UI_BORDER_SPACING - btnWidth - 1, self.enabledModsTickbox.y, btnWidth, BUTTON_HGT, getText("UI_modselector_modOptions"), self, ModListPanel.onOptionMouseDown)
    self.modOptionsButton.internal = "ModOptions"
    self.modOptionsButton:initialise()
    self.modOptionsButton:instantiate()
    self:addChild(self.modOptionsButton)

    self.modList = ModSelector.ModListBox:new(0, self.modOptionsButton:getBottom() + UI_BORDER_SPACING, self.width, self.height - self.modOptionsButton:getBottom() - UI_BORDER_SPACING, self.model)
    self.modList:initialise();
    self.modList:instantiate();
    self:addChild(self.modList)
end

function ModListPanel:onSortChanged(combo)
    local data = combo:getOptionData(combo.selected)
    self.model:setSort(data)
end

function ModListPanel:onEnabledModsTickbox()
    if self.enabledModsTickbox.selected[1] then
        self.disabledModsTickbox:setSelected(1, false)
    end
    self:updateView()
end

function ModListPanel:onDisabledModsTickbox()
    if self.disabledModsTickbox.selected[1] then
        self.enabledModsTickbox:setSelected(1, false)
    end
    self:updateView()
end

function ModListPanel:recalcSize()
    ISPanelJoypad.recalcSize(self)
    self.modList:setWidth(self.width)
    self.modList:setHeight(self.height - self.modOptionsButton:getBottom() - UI_BORDER_SPACING)
    self.modList:recalcSize()

    self.sortLabel:setX(self.filterCombo:getRight() + UI_BORDER_SPACING)
    self.sortCombo:setX(self.sortLabel:getRight() + UI_BORDER_SPACING)
    self.searchEntry:setWidth((self.width - self.sortCombo:getRight() - UI_BORDER_SPACING * 3 - self.searchLabel:getWidth()))
    self.searchEntry:setX(self.width - UI_BORDER_SPACING - self.searchEntry:getWidth() - 1)
    self.searchLabel:setX(self.searchEntry:getX() - self.searchLabel:getWidth() - UI_BORDER_SPACING)

    self.modOptionsButton:setX(self.width - self.modOptionsButton.width - UI_BORDER_SPACING - 1)
end

function ModListPanel:applyFilters()
    local category = self.filterCombo.options[self.filterCombo.selected]
    local searchWord = string.lower(self.searchEntry:getInternalText())
    self.model:filterMods(category, searchWord, self.isFavoriteMode, self.enabledModsTickbox.selected[1], self.disabledModsTickbox.selected[1], self.hiddenModsTickbox.selected[1])
end

function ModListPanel:onOptionMouseDown(button, x, y)
    if button.internal == "ModOptions" then
        if #PZAPI.ModOptions.Data == 0 then return end
        ModSelector.instance:setVisible(false)
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local width = screenW * 0.7
        local height = screenH * 0.8
        local x = (screenW - width) / 2
        local y = (screenH - height) / 2
        local optionsPanel = ModOptionsScreen:new(x, y, width, height)
        optionsPanel:initialise()
        optionsPanel:instantiate()
        optionsPanel:addToUIManager()
        optionsPanel:bringToTop()
        optionsPanel:setCapture(true)
        optionsPanel.returnToUI = ModSelector.instance
        optionsPanel:setVisible(true, self.joyfocus)
    end
end