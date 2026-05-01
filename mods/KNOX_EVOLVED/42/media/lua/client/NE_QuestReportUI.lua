require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"

NE_QuestReportUI = ISPanel:derive("NE_QuestReportUI")

local QUEST_REPORT_FULLTYPE = "KNOX_EVOLVED.NE_QuestReport"

function NE_QuestReportUI.closeSelf(target, _button)
    target:removeFromUIManager()
end

function NE_QuestReportUI:createChildren()
    local pad = 15
    local btnH = 25

    self.richText = ISRichTextPanel:new(pad, pad, self.width - pad * 2, self.height - pad * 3 - btnH)
    self.richText.autosetheight = false
    self.richText.clip = true
    self.richText.background = false
    self.richText.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    self.richText.marginLeft = 0
    self.richText.marginTop = 0
    self.richText.marginRight = 0
    self.richText.marginBottom = 0
    self.richText:initialise()
    self.richText:instantiate()
    self.richText:addScrollBars(true)

    local title = getText("IGUI_NE_Report_Title")
    local intro = getText("IGUI_NE_Report_Intro")
    local mission = getText("IGUI_NE_Report_Mission")
    local locs = string.format("%s <LINE> %s <LINE> %s <LINE> %s",
        getText("IGUI_NE_Report_Loc1"), getText("IGUI_NE_Report_Loc2"),
        getText("IGUI_NE_Report_Loc3"), getText("IGUI_NE_Report_Loc4"))
    local note = getText("IGUI_NE_Report_Note")

    -- <H1> 直後に <TEXT> 必須（</H1> はフォントを戻さないため、未指定だと本文が Large のまま）
    -- <CENTRE> … ISRichTextPanel:processCommand（バニラ）で行の orient を centre に
    local content = " <RGB:1,1,1> <H1> " .. title .. " </H1> <LINE> <LINE> <TEXT> <CENTRE> <RGB:1,1,1> "
    content = content .. intro .. " <LINE> <LINE> "
    content = content .. mission .. " <LINE> <LINE> "
    content = content .. locs .. " <LINE> <LINE> "
    content = content .. " <CENTRE> <RGB:1,0.5,0.5> " .. note .. " "

    self.richText:setText(content)
    self.richText:paginate()
    self:addChild(self.richText)

    self.closeBtn = ISButton:new(pad, self.height - pad - btnH, self.width - pad * 2, btnH,
        getText("UI_btn_close"), self, NE_QuestReportUI.closeSelf)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)
end

function NE_QuestReportUI:initialise()
    ISPanel.initialise(self)
    self:createChildren()
end

function NE_QuestReportUI:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 }
    o:setWantKeyEvents(true)
    return o
end

local function findQuestReportInContextItems(items)
    for _, v in ipairs(items) do
        if instanceof(v, "InventoryItem") then
            if v:getFullType() == QUEST_REPORT_FULLTYPE then
                return v
            end
        elseif v.items then
            for _, it in ipairs(v.items) do
                if it:getFullType() == QUEST_REPORT_FULLTYPE then
                    return it
                end
            end
        end
    end
    return nil
end

local function onFillInventoryObjectContextMenu(player, context, items)
    if not findQuestReportInContextItems(items) then
        return
    end
    context:addOption(getText("IGUI_NE_Report_ContextExamine"), player, function(playerNum)
        local ui = NE_QuestReportUI:new(0, 0, 600, 650)
        ui:initialise()
        ui:addToUIManager()
        ui:centerOnScreen(playerNum)
    end)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
