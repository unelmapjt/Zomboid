require "ISUI/ISPanelJoypad"
require "OptionScreens/MainScreen"
require "OptionScreens/ModSelector/ModSelector"

local MLOS_sorting = require('OptionScreens/ModSelector/MLOS_sorting')

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local JOYPAD_TEX_SIZE = 32
local BUTTON_PADDING = JOYPAD_TEX_SIZE + UI_BORDER_SPACING*2

function ISButton:enableBlueColor()
    local GHC = getCore():getGoodHighlitedColor()
    local r, g, b = 0.168, 0.615, 0.952
    self:setBackgroundRGBA(r, g, b, 0.25)
    self:setBackgroundColorMouseOverRGBA(r, g, b, 0.50)
    self:setBorderRGBA(r, g, b, 1)
end

local original_onKeyRelease = MainScreen.onKeyRelease
function MainScreen:onKeyRelease(key)
    if ModSelector.instance and ModSelector.instance:isReallyVisible() then
        ModSelector.instance:onKeyRelease(key)
        return
    end

    original_onKeyRelease(self, key)
end

function ModSelector:create()
    local listY = UI_BORDER_SPACING*2 + math.max(FONT_HGT_LARGE, BUTTON_HGT) + 1
    local listHgt = self.height - listY - BUTTON_HGT - UI_BORDER_SPACING*2 - 1
    self.modListPanel = ModSelector.ModListPanel:new(UI_BORDER_SPACING+1, listY, self.width/2-UI_BORDER_SPACING, listHgt, self.model)
    self.modListPanel:initialise()
    self.modListPanel:instantiate()
    self.modListPanel:setAnchorLeft(true)
    self.modListPanel:setAnchorRight(true)
    self.modListPanel:setAnchorTop(true)
    self.modListPanel:setAnchorBottom(true)
    self:addChild(self.modListPanel)

    local left = self.modListPanel:getRight() + UI_BORDER_SPACING
    local top = self.modListPanel:getY()
    self.modInfoPanel = ModInfoPanel:new(left, top, self.width - UI_BORDER_SPACING - left - 1, self.modListPanel.height)
    self.modInfoPanel:setAnchorBottom(true)
    self.modInfoPanel:addScrollBars()
    self.modInfoPanel:setScrollChildren(true)
    self:addChild(self.modInfoPanel)
    self.modInfoPanel:setVisible(false)

    local btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_back"))
    self.backButton = ISButton:new(UI_BORDER_SPACING+1, self.height - BUTTON_HGT - UI_BORDER_SPACING - 1, btnWidth, BUTTON_HGT, getText("UI_btn_back"), self, ModSelector.onOptionMouseDown);
    self.backButton.internal = "BACK";
    self.backButton:initialise();
    self.backButton:instantiate();
    self.backButton:setAnchorLeft(true);
    self.backButton:setAnchorRight(false);
    self.backButton:setAnchorTop(false);
    self.backButton:setAnchorBottom(true);
    self.backButton:enableCancelColor()
    self.backButton:setFont(UIFont.Small);
    self.backButton:ignoreWidthChange();
    self.backButton:ignoreHeightChange();
    self:addChild(self.backButton);

    local presetWidth = self.modListPanel:getRight() - self.backButton:getRight() - UI_BORDER_SPACING
    self.presetPanel = ModListPresets:new(self.backButton:getRight() + UI_BORDER_SPACING, self.backButton.y, presetWidth, BUTTON_HGT, self.model)
    self.presetPanel:setAnchorLeft(true);
    self.presetPanel:setAnchorRight(false);
    self.presetPanel:setAnchorTop(false);
    self.presetPanel:setAnchorBottom(true);
    self.presetPanel:ignoreWidthChange();
    self.presetPanel:ignoreHeightChange();
    self:addChild(self.presetPanel)

    btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_accept"))
    self.acceptButton = ISButton:new(self.width - UI_BORDER_SPACING - btnWidth - 1, self.backButton.y, btnWidth, BUTTON_HGT, getText("UI_btn_accept"), self, ModSelector.onOptionMouseDown);
    self.acceptButton.internal = "ACCEPT";
    self.acceptButton:initialise();
    self.acceptButton:instantiate();
    self.acceptButton:setAnchorLeft(false);
    self.acceptButton:setAnchorRight(true);
    self.acceptButton:setAnchorTop(false);
    self.acceptButton:setAnchorBottom(true);
    self.acceptButton:enableAcceptColor()
    self.acceptButton:setFont(UIFont.Small);
    self.acceptButton:ignoreWidthChange();
    self.acceptButton:ignoreHeightChange();
    self:addChild(self.acceptButton);

    btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_sort_apply"))
    self.sortAndApplyButton = ISButton:new(self.acceptButton.x - btnWidth - UI_BORDER_SPACING, self.backButton.y, btnWidth, BUTTON_HGT, getText("UI_btn_sort_apply"), self, self.onSortAndApply);
    self.sortAndApplyButton:initialise();
    self.sortAndApplyButton:instantiate();
    self.sortAndApplyButton:setAnchorLeft(false);
    self.sortAndApplyButton:setAnchorRight(true);
    self.sortAndApplyButton:setAnchorTop(false);
    self.sortAndApplyButton:setAnchorBottom(true);
    self.sortAndApplyButton:enableBlueColor()
    self.sortAndApplyButton:setFont(UIFont.Small);
    self.sortAndApplyButton:ignoreWidthChange();
    self.sortAndApplyButton:ignoreHeightChange();
    self:addChild(self.sortAndApplyButton);

    btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_mods_ModsOrder"))
    self.modOrderbtn = ISButton:new(self.sortAndApplyButton.x - btnWidth - UI_BORDER_SPACING, self.backButton.y, btnWidth, BUTTON_HGT, getText("UI_mods_ModsOrder"), self, ModSelector.onOptionMouseDown);
    self.modOrderbtn.internal = "MODSORDER";
    self.modOrderbtn:initialise();
    self.modOrderbtn:instantiate();
    self.modOrderbtn:setAnchorLeft(false);
    self.modOrderbtn:setAnchorRight(true);
    self.modOrderbtn:setAnchorTop(false);
    self.modOrderbtn:setAnchorBottom(true);
    self.modOrderbtn.borderColor = {r=1, g=1, b=1, a=0.1};
    self.modOrderbtn:setFont(UIFont.Small);
    self.modOrderbtn:ignoreWidthChange();
    self.modOrderbtn:ignoreHeightChange();
    self:addChild(self.modOrderbtn);

    btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_mods_MapsOrder"))
    self.mapOrderbtn = ISButton:new(self.modOrderbtn.x - btnWidth - UI_BORDER_SPACING, self.backButton.y, btnWidth, BUTTON_HGT, getText("UI_mods_MapsOrder"), self, ModSelector.onOptionMouseDown);
    self.mapOrderbtn.internal = "MAPSORDER";
    self.mapOrderbtn.textColor = {r=1.0, g=0.4, b=0.05, a=1.0}
    self.mapOrderbtn:initialise();
    self.mapOrderbtn:instantiate();
    self.mapOrderbtn:setAnchorLeft(false);
    self.mapOrderbtn:setAnchorRight(true);
    self.mapOrderbtn:setAnchorTop(false);
    self.mapOrderbtn:setAnchorBottom(true);
    self.mapOrderbtn.borderColor = {r=1, g=1, b=1, a=0.1};
    self.mapOrderbtn:setFont(UIFont.Small);
    self.mapOrderbtn:ignoreWidthChange();
    self.mapOrderbtn:ignoreHeightChange();
    self:addChild(self.mapOrderbtn);

    btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_ResetLua"))
    self.reloadLuaButton = ISButton:new(self.width - btnWidth - UI_BORDER_SPACING-1, UI_BORDER_SPACING+1, btnWidth, BUTTON_HGT, getText("UI_ResetLua") , self, function() getCore():ResetLua("default", "Force") end);
    self.reloadLuaButton:initialise();
    self.reloadLuaButton:instantiate();
    self.reloadLuaButton:setAnchorLeft(false);
    self.reloadLuaButton:setAnchorRight(true);
    self.reloadLuaButton:setAnchorTop(true);
    self.reloadLuaButton:setAnchorBottom(false);
    self.reloadLuaButton.borderColor = {r=0.2, g=0.8, b=1, a=1};
    self.reloadLuaButton.textColor = {r=0.2, g=0.8, b=1, a=1};
    self.reloadLuaButton:setFont(UIFont.Small);
    self.reloadLuaButton:ignoreWidthChange();
    self.reloadLuaButton:ignoreHeightChange();
    self:addChild(self.reloadLuaButton);

    btnWidth = BUTTON_PADDING + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_help"))
    self.helpButton = ISButton:new(self.reloadLuaButton.x - btnWidth - UI_BORDER_SPACING, self.reloadLuaButton.y, btnWidth, BUTTON_HGT, getText("UI_btn_help"), self, ModSelector.onOptionMouseDown);
    self.helpButton.internal = "HELP";
    self.helpButton:initialise();
    self.helpButton:instantiate();
    self.helpButton:setAnchorLeft(false);
    self.helpButton:setAnchorRight(true);
    self.helpButton:setAnchorTop(true);
    self.helpButton:setAnchorBottom(false);
    self.helpButton.borderColor = {r=1, g=1, b=1, a=0.1};
    self.helpButton:setFont(UIFont.Small);
    self.helpButton:ignoreWidthChange();
    self.helpButton:ignoreHeightChange();
    self:addChild(self.helpButton);
end

function ModSelector:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    ISPanelJoypad.prerender(self)
    self:drawTextCentre(getText("UI_mods_SelectMods"), self.width / 2, 10, 1, 1, 1, 1, UIFont.Large)

    local total, active, current = 0, 0, 0

    if self.model and self.model.mods then
        for _, mod in pairs(self.model.mods) do
            total = total + 1
            if mod.defaultActive then active = active + 1 end
            if mod.isActive then current = current + 1 end
        end
    end

    local diff = current - active
    
    local txtX, txtY, font = UI_BORDER_SPACING + 1, 15, UIFont.Medium
    
    local str1 = getText("UI_LoadGameScreen_Mods") .. " " .. active
    self:drawText(str1, txtX, txtY, 1, 1, 1, 1, font)
    txtX = txtX + getTextManager():MeasureStringX(font, str1)
    
    if diff ~= 0 then
        local str2 = ""
        local r, g, b = 1, 1, 1
        
        if diff > 0 then
            str2 = " + " .. diff .. " "
            r, g, b = 0.2, 0.8, 1
        else
            str2 = " - " .. math.abs(diff) .. " "
            r, g, b = 1.0, 0.2, 0.2
        end
        
        self:drawText(str2, txtX, txtY, r, g, b, 1, font)
        txtX = txtX + getTextManager():MeasureStringX(font, str2)
    end
    
    local str3 = " " .. getText("UI_modselector_separator") .. " " .. total
    self:drawText(str3, txtX, txtY, 1, 1, 1, 1, font)
end

function ModSelector:selectModByInfo(modInfo)
    if not modInfo then return end

    local modList = self.modListPanel.modList
    local modIdToSelect = modInfo:getId()
    for i, item in ipairs(modList.items) do
        if item.item.modId == modIdToSelect then
            modList.selected = i
            modList:ensureVisible(i)
            break
        end
    end

    self.modInfoPanel:updateView(modInfo)
end

function ModSelector:updateView()
    self.modListPanel:updateView()
    self.presetPanel:updateView()

    self.mapOrderbtn.enable = self.model:checkMapConflicts()

    if self.modInfoPanel and self.modInfoPanel:getIsVisible() and self.modInfoPanel.modInfo then
        self.modInfoPanel:updateView(self.modInfoPanel.modInfo)
    end
end

function ModSelector:onSortAndApply()
    local activeModItems = {}
    for modId, modData in pairs(self.model.mods) do
        if modData.isActive then
            table.insert(activeModItems, { item = modData })
        end
    end

    local sortedModIDs = MLOS_sorting:SortModsOrder(activeModItems)

    local modArray = self.model:getActiveMods():getMods()
    modArray:clear()
    for _, modId in ipairs(sortedModIDs) do
        modArray:add(modId)
    end
    
    self:onAccept()
end

function ModSelector:update()
    ISPanelJoypad.update(self)

    if not self.modListPanel.modList.items or #self.modListPanel.modList.items == 0 then return end
    if self.modListPanel.searchEntry:isFocused() then return end

    local up = isKeyDown(Keyboard.KEY_UP)
    local down = isKeyDown(Keyboard.KEY_DOWN)

    if up or down then
        local now = getTimestampMs()
        local move = false
        local direction = up and "up" or "down"

        if self.lastKey ~= direction then
            self.lastKey = direction
            self.repeatTimer = now + 500
            move = true
        elseif now > self.repeatTimer then
            self.repeatTimer = now + 50
            move = true
        end

        if move then
            local modList = self.modListPanel.modList
            local step = isKeyDown(Keyboard.KEY_LSHIFT) and 5 or 1
            if up then
                modList.selected = math.max(1, modList.selected - step)
            else
                modList.selected = math.min(#modList.items, modList.selected + step)
            end
            
            local selectedItem = modList.items[modList.selected].item
            if selectedItem and selectedItem.modInfo then
                 self.modInfoPanel:updateView(selectedItem.modInfo)
            end

            modList:ensureVisible(modList.selected)
        end
    else
        self.lastKey = nil
    end
end

function ModSelector:onKeyRelease(key)
    if self.modListPanel.searchEntry:isFocused() then
        if key == Keyboard.KEY_ESCAPE then
            self.backButton:forceClick()
        end
        return
    end

    if key == Keyboard.KEY_ESCAPE then
        self.backButton:forceClick()
        return
    end

    if key == Keyboard.KEY_RETURN then
        self.acceptButton:forceClick()
        return
    end

    local modList = self.modListPanel.modList
    if not modList or not modList.items or #modList.items == 0 or modList.selected == -1 then
        return
    end

    if key == Keyboard.KEY_SPACE then
        local selectedMod = modList.items[modList.selected].item
        self.model:forceActivateMods(selectedMod.modInfo, not selectedMod.isActive)
    end
end