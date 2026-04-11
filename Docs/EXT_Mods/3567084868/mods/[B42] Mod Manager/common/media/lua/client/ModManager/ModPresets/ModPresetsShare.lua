require "ISUI/ISPanelJoypad"
require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"
require "ISUI/ISButton"

ModPresetsShare = ISPanelJoypad:derive("ModPresetsShare")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ENTRY_HGT = BUTTON_HGT

function ModPresetsShare:initialise()
    ISPanelJoypad.initialise(self)
    self:createChildren()
end

function ModPresetsShare:createChildren()
    local y = UI_BORDER_SPACING * 4
    local btnWid = 100

    local modIds = {}
    for _, modId in ipairs(self.presetData) do
        table.insert(modIds, modId)
    end

    local mpModIds = {}
    local workshopIds = {}
    for _, modId in ipairs(modIds) do
        if self.model.mods[modId] and self.model.mods[modId].workshopIDStr and self.model.mods[modId].workshopIDStr ~= "" then
            table.insert(mpModIds, modId)
            table.insert(workshopIds, self.model.mods[modId].workshopIDStr)
        end
    end

    local soloString = self.presetName .. ":" .. table.concat(modIds, ";") .. ";"
    local modIdsString = table.concat(mpModIds, ";") .. ";"
    local workshopIdsString = table.concat(workshopIds, ";")

    y = self:createRow(getText("UI_mainscreen_solo") .. ":", soloString, y)

    y = y + UI_BORDER_SPACING

    y = self:createRow(getText("UI_optionscreen_multiplayer") .. " (Mods)" .. ":", modIdsString, y)

    y = y + UI_BORDER_SPACING

    y = self:createRow(getText("UI_optionscreen_multiplayer") .. " (WorkshopItems)" .. ":", workshopIdsString, y)

    y = y + UI_BORDER_SPACING

    local requiredHeight = y + BUTTON_HGT + UI_BORDER_SPACING
    self:setY(self.y + (self.height - requiredHeight) / 2)
    self:setHeight(requiredHeight)

    self.closeButton = ISButton:new(self.width / 2 - btnWid / 2, self.height - UI_BORDER_SPACING - BUTTON_HGT, btnWid, BUTTON_HGT, getText("UI_btn_close"), self, self.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton:setAnchorTop(false)
    self.closeButton:setAnchorBottom(true)
    self:addChild(self.closeButton)

    self:insertNewLineOfButtons(self.closeButton)
end

function ModPresetsShare:createRow(title, content, y)
    local label = ISLabel:new(UI_BORDER_SPACING, y, FONT_HGT_MEDIUM, title, 1, 1, 1, 1, UIFont.Medium, true)
    label:initialise()
    label:instantiate()
    self:addChild(label)
    y = y + FONT_HGT_MEDIUM + 4

    local copyBtn = ISButton:new(UI_BORDER_SPACING, y, ENTRY_HGT, ENTRY_HGT, "", self, self.onCopy)
    copyBtn:initialise()
    copyBtn:instantiate()
    copyBtn:setImage(getTexture("media/ui/ModManager/Copy.png"))
    copyBtn.internal = content
    copyBtn:setTooltip(getText("UI_modpresets_copy"))
    self:addChild(copyBtn)

    local entry = ISTextEntryBox:new(content, copyBtn:getRight() + UI_BORDER_SPACING, y, self.width - (UI_BORDER_SPACING * 3) - ENTRY_HGT, ENTRY_HGT)
    entry:initialise()
    entry:instantiate()
    entry:setEditable(false)
    entry:setSelectable(true)
    self:addChild(entry)

    self:insertNewLineOfButtons(copyBtn, entry)

    return y + ENTRY_HGT
end

function ModPresetsShare:onCopy(button)
    if button.internal then
        Clipboard.setClipboard(button.internal)
    end
end

function ModPresetsShare:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    if self.returnToUI then
        self.returnToUI:setVisible(true)
        if self.joyfocus then
            self.returnToUI.joyfocus = self.joyfocus
            self.joyfocus.focus = self.returnToUI
        end
    end
end

function ModPresetsShare:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawTextCentre(getText("UI_btn_share") .. ": " .. self.presetName, self.width / 2, UI_BORDER_SPACING + 1, 1, 1, 1, 1, UIFont.Medium)
end

function ModPresetsShare:render()
    ISPanelJoypad.render(self)
end

function ModPresetsShare:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForB(self.closeButton)
end

function ModPresetsShare:new(x, y, width, height, model, presetName, presetData)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=1, g=1, b=1, a=0.2}
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.model = model
    o.presetName = presetName
    o.presetData = presetData
    o.anchorLeft = true;
    o.anchorRight = true;
    o.anchorTop = true;
    o.anchorBottom = true;
    return o
end