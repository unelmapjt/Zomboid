require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModInfoPanel"

local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local LABEL_HGT = FONT_HGT_MEDIUM + 6
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

ModInfoPanel.Title = ISPanelJoypad:derive("ModInfoPanelTitle")

function ModInfoPanel.Title:createChildren()
    self.title = ISLabel:new(UI_BORDER_SPACING+1, 0, LABEL_HGT, getText("UI_modselector_title"), 1.0, 1.0, 1.0, 1.0, UIFont.Medium, true)
    self:addChild(self.title)

    self.enableButton = ISButton:new(0, 0, 100, BUTTON_HGT, "", self, self.onEnableClick)
    self.enableButton:initialise()
    self.enableButton:setAnchorLeft(false)
    self.enableButton:setAnchorRight(true)
    self.enableButton:setFont(UIFont.Small)
    self:addChild(self.enableButton)

    self.favoriteButton = ISButton:new(0, 0, 100, BUTTON_HGT, "", self, self.onFavoriteClick)
    self.favoriteButton:initialise()
    self.favoriteButton:setAnchorLeft(false)
    self.favoriteButton:setAnchorRight(false)
    self.favoriteButton:setFont(UIFont.Small)
    self:addChild(self.favoriteButton)

    self.hideButton = ISButton:new(0, 0, 100, BUTTON_HGT, "", self, self.onHideClick)
    self.hideButton:initialise()
    self.hideButton:setAnchorLeft(false)
    self.hideButton:setAnchorRight(false)
    self.hideButton:setFont(UIFont.Small)
    self:addChild(self.hideButton)

    local titleCenterY = (LABEL_HGT + UI_BORDER_SPACING*2 + 1) / 2
    self.title:setY(titleCenterY - self.title:getHeight() / 2)
    local buttonY = titleCenterY - BUTTON_HGT / 2
    self.enableButton:setY(buttonY)
    self.favoriteButton:setY(buttonY)
    self.hideButton:setY(buttonY)
end

function ModInfoPanel.Title:onFavoriteClick(button)
    if not self.parent or not self.parent.modInfo then return end
    local model = self.parent.parent.model
    local modId = self.parent.modInfo:getId()
    model:setFavorite(modId, not model:isFavorite(modId))
end

function ModInfoPanel.Title:onHideClick(button)
    if not self.parent or not self.parent.modInfo then return end
    local modSelector = self.parent.parent
    local model = modSelector.model
    local modId = self.parent.modInfo:getId()
    local isHidden = model:isHidden(modId)

    local modList = modSelector.modListPanel.modList
    local oldIndex = modList.selected
    local oldItemCount = #modList.items

    model:setHidden(modId, not isHidden)

    if isHidden then
        return
    end

    local newIndex = oldIndex
    if oldIndex >= oldItemCount then
        newIndex = oldItemCount - 1
    end
    newIndex = math.max(1, newIndex)

    if #modList.items > 0 then
        newIndex = math.min(newIndex, #modList.items)
        modList.selected = newIndex
        modSelector.modInfoPanel:updateView(modList.items[newIndex].item.modInfo)
    else
        modList.selected = -1
        modSelector.modInfoPanel:setVisible(false)
    end
end

function ModInfoPanel.Title:onEnableClick(button)
    if not self.parent or not self.parent.modInfo then return end
    local model = self.parent.parent.model
    local modInfo = self.parent.modInfo
    local modId = modInfo:getId()
    model:forceActivateMods(modInfo, not model:isModActive(modId))
end

function ModInfoPanel.Title:setModInfo(modInfo)
    self.title.name = modInfo:getName()
    local model = self.parent.parent.model
    local modId = modInfo:getId()

    if model:isHidden(modId) then
        self.hideButton:setTitle(getText("UI_modselector_btn_show"))
    else
        self.hideButton:setTitle(getText("UI_modselector_btn_hide"))
    end
    if model:isFavorite(modId) then
        self.favoriteButton:setTitle(getText("UI_modselector_btn_unfavorite"))
    else
        self.favoriteButton:setTitle(getText("UI_modselector_btn_favorite"))
    end
    if model:isModActive(modId) then
        self.enableButton:setTitle(getText("UI_modselector_btn_disable"))
    else
        self.enableButton:setTitle(getText("UI_modselector_btn_enable"))
    end

    self.hideButton:setWidthToTitle(UI_BORDER_SPACING); self.hideButton:setWidth(self.hideButton:getWidth() + 40)
    self.favoriteButton:setWidthToTitle(UI_BORDER_SPACING); self.favoriteButton:setWidth(self.favoriteButton:getWidth() + 40)
    self.enableButton:setWidthToTitle(UI_BORDER_SPACING); self.enableButton:setWidth(self.enableButton:getWidth() + 40)

    self.hideButton:setX(self.width - self.hideButton:getWidth() - UI_BORDER_SPACING)
    self.favoriteButton:setX(self.hideButton:getX() - self.favoriteButton:getWidth() - UI_BORDER_SPACING)
    self.enableButton:setX(self.favoriteButton:getX() - self.enableButton:getWidth() - UI_BORDER_SPACING)
end

function ModInfoPanel.Title:new(x, y, width)
    local o = ISPanelJoypad:new(x, y, width, LABEL_HGT + UI_BORDER_SPACING*2 + 1)
    setmetatable(o, self)
    self.__index = self
    return o
end