require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModInfoPanel"
require "OptionScreens/ModSelector/ModInfoPanelInteractionParam"

local UI_BORDER_SPACING = 10

local function fetchChangelog(modID)
    local reader = getModFileReader(modID, "ChangeLog.txt", false)
    local isMarkdown = false
    if not reader then
        isMarkdown = true
        reader = getModFileReader(modID, "ChangeLog.md", false)
    end

    if not reader then return nil end

    local fileContent = ""
    local line = reader:readLine()
    while line do
        fileContent = fileContent .. line .. "\n"
        line = reader:readLine()
    end
    reader:close()

    local changelogs, pattern = nil, isMarkdown and "###%s*(.-)%s*###%s*(.-)%s*#" or "%[ ([^%]]+)% ](.-)%[ ------ %]"

    for title, contents in string.gmatch(fileContent, pattern) do
        if title ~= "ALERT_CONFIG" then
            if not changelogs then
                changelogs = {}
            end
            local cleanedContents = contents:gsub("^%s*\n", "")
            table.insert(changelogs, {title = title, contents = cleanedContents})
        end
    end

    return changelogs
end

ModInfoPanel.Changelog = ModInfoPanel.InteractionParam:derive("ModInfoPanelChangelog")

function ModInfoPanel.Changelog:new(x, y, width, height)
    local o = ModInfoPanel.InteractionParam.new(self, x, y, width, "Changelog")
    o.name = getText("UI_modinfopanel_Changelog")
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.modDict = {}
    return o
end

function ModInfoPanel.Changelog:createChildren()
    self.richText = ISRichTextPanel:new(self.borderX + UI_BORDER_SPACING, 3, self.width - self.borderX - 12, self.height - 6)
    self.richText:initialise()
    self.richText:instantiate()
    self.richText:setAnchorRight(true)
    self.richText:setAnchorBottom(true)
    self.richText.defaultFont = UIFont.Small
    self.richText.autosetheight = false
    self.richText.clip = true
    self.richText:noBackground()
    self.richText.marginLeft = 0
    self.richText.marginTop = 0
    self.richText.marginRight = 0
    self.richText.marginBottom = 0
    self.richText:addScrollBars()
    self:addChild(self.richText)
end

function ModInfoPanel.Changelog:render()
    ModInfoPanel.InteractionParam.render(self)
end

function ModInfoPanel.Changelog:onMouseWheel(del)
    return self.richText:onMouseWheel(del)
end

function ModInfoPanel.Changelog:setModInfo(modInfo)
    local modID = modInfo:getId()
    local changelogs = fetchChangelog(modID)

    local text_parts = {}
    table.insert(text_parts, " <TEXT> ")

    if changelogs and #changelogs > 0 then
        for i = #changelogs, 1, -1 do
            local entry = changelogs[i]
            local title = entry.title or ""
            local contents = entry.contents or ""

            table.insert(text_parts, " <RGB:0.8,0.8,0.8> " .. title .. " <LINE> ")
            table.insert(text_parts, " <RGB:0.8,0.8,0.8> " .. luautils.trim(contents))
            table.insert(text_parts, " <LINE> <LINE> ")
        end
    end

    self.richText:setText(table.concat(text_parts, ""))
    self.richText:paginate()
    self.richText:setYScroll(0)
end