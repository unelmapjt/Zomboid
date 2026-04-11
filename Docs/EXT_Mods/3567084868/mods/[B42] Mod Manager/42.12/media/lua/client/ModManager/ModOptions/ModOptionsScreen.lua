require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "ISUI/ISControllerTestPanel"
require "ISUI/ISVolumeControl"
require "ISUI/ISDuplicateKeybindDialog"
require "ISUI/ISSetKeybindDialog"
require "OptionScreens/MainOptions"
require "PZAPI/ModOptions"

local ModManagerData = require "ModManager/Utilities/ModListData"

function PZAPI.ModOptions.Options:addImage(imagePath, secondParam)
    local option = { type = "image", path = imagePath, fit = false, minWidth = nil }
    if type(secondParam) == "boolean" then
        option.fit = secondParam
    elseif type(secondParam) == "number" then
        option.fit = false
        option.minWidth = secondParam
    end
    table.insert(self.data, option)
    return option
end

function MainOptions:addModOptionsPanel() end

ModOptionsScreen = ISPanelJoypad:derive("ModOptionsScreen")

local ModOptionsScreenListBox = ISScrollingListBox:derive("ModOptionsScreenListBox")
local ModOptionsScreenPanel = ISPanelJoypad:derive("ModOptionsScreenPanel")

function ModOptionsScreenListBox:doDrawItem(y, item, alt)
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    elseif self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
        self:drawRect(1, y + 1, self:getWidth() - 2, self.itemheight - 4, 0.95, 0.05, 0.05, 0.05)
    end
    local dx = 10
    local dy = (self.itemheight - getTextManager():getFontFromEnum(self.font):getLineHeight()) / 2
    local r, g, b = 0.9, 0.9, 0.9
    if item.searchFound then
        r, g, b = 0, 0.9, 0
    end
    self:drawText(item.text, dx, y + dy, r, g, b, 0.9, self.font)
    return y + self.itemheight
end

function ModOptionsScreenPanel:prerender()
    self:doRightJoystickScrolling(20, 20)
    ISPanelJoypad.prerender(self)
    if self.labels then
        for settingName, label in pairs(self.labels) do
            if label and label.searchFound then
                label:setColor(0, 1, 0)
            elseif label then
                label:setColor(1, 1, 1)
            end
        end
    end
    self:setStencilRect(1, 1, self.width - 2, self.height - 2)
end

function ModOptionsScreenPanel:render()
    self:drawRectBorderStatic(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    ISPanelJoypad.render(self)
    self:clearStencilRect()
end

function ModOptionsScreenPanel:onMouseWheel(del)
    if self:getScrollHeight() > 0 then
        self:setYScroll(self:getYScroll() - (del * 40))
        return true
    end
    return false
end

function ModOptionsScreen:initialise()
    ISPanelJoypad.initialise(self)
    ModOptionsScreen.instance = self
    self:loadModsByDateAdded()
    self:createChildren()
    self.originalKeyPressHandler = MainOptions.keyPressHandler
    MainOptions.keyPressHandler = function(...) self:keyPressHandler(...) end
end

function ModOptionsScreen:loadModsByDateAdded()
    self.modsByDateAdded = {}
    local modListData = ModManagerData:load()
    if modListData and modListData.mods then
        local sorted = {}
        for modID, data in pairs(modListData.mods) do
            table.insert(sorted, { id = modID, index = data.index })
        end
        table.sort(sorted, function(a, b) return (a.index or 0) < (b.index or 0) end)
        
        for _, item in ipairs(sorted) do
            table.insert(self.modsByDateAdded, item.id)
        end
    end
end

function ModOptionsScreen:getModIndex(modID)
    if not modID then return -1 end
    for i, id in ipairs(self.modsByDateAdded) do
        if id == modID then
            return i
        end
    end
    return -1
end

function ModOptionsScreen:onSortChanged()
    local selectedModID = nil
    if self.listbox.selected > 0 and self.listbox.items[self.listbox.selected] then
        selectedModID = self.listbox.items[self.listbox.selected].item.page.modOptionsID
    end

    if PZAPI and PZAPI.ModOptions then
        for _, options in ipairs(PZAPI.ModOptions.Data) do
            for _, option in ipairs(options.data) do
                if option.element then
                    if option.type == "textentry" then
                         option.pendingValue = option.element:getInternalText()
                    elseif option.type == "tickbox" then
                         option.pendingValue = option.element:isSelected(1)
                    elseif option.type == "multipletickbox" and option.values then
                        for i = 1, #option.element.options do
                            if option.values[i] then 
                                option.values[i].pendingValue = option.element:isSelected(i)
                            end
                        end
                    elseif option.type == "combobox" then
                        option.pendingValue = option.element.selected
                    elseif option.type == "slider" then
                        option.pendingValue = option.element:getCurrentValue()
                    elseif option.type == "colorpicker" and option.element.backgroundColor then
                        option.pendingColor = option.element.backgroundColor
                    elseif option.type == "keybind" then
                        option.pendingValue = tostring(option.element.keyCode or 0)
                    end
                end
            end
        end
    end

    local wasChanged = self.optionsChanged; self:sortAndRefillListbox(); self.optionsChanged = wasChanged

    self.applyButton:setEnable(self.optionsChanged)

    if selectedModID then
        for i, item in ipairs(self.listbox.items) do
            if item.item.page.modOptionsID == selectedModID then
                self.listbox.selected = i
                self:onMouseDownListbox(item.item)
                break
            end
        end
    end
end

function ModOptionsScreen:sortAndRefillListbox()
    if not self.listbox then return end
    self.listbox:clear()
    if not PZAPI or not PZAPI.ModOptions or not PZAPI.ModOptions.Data then return end
    local sortedModOptions = {}
    for _, options in ipairs(PZAPI.ModOptions.Data) do
        if options and options.modOptionsID then
            table.insert(sortedModOptions, options)
        end
    end
    if self.sortCombo and self.sortCombo.selected == 2 then
        table.sort(sortedModOptions, function(a, b)
            return self:getModIndex(a.modOptionsID) > self:getModIndex(b.modOptionsID)
        end)
    else
        table.sort(sortedModOptions, function(a, b)
            local nameA = a.name and getText(a.name) or a.name or ""
            local nameB = b.name and getText(b.name) or b.name or ""
            return nameA < nameB
        end)
    end
    for _, options in ipairs(sortedModOptions) do
        local panel = self:createPanel(options)
        if panel then
            local item = {}
            item.page = options
            item.panel = panel
            local displayName = options.name and getText(options.name) or options.name or options.modOptionsID
            self.listbox:addItem(displayName, item)
        end
    end
    if #self.listbox.items > 0 then
        self:onMouseDownListbox(self.listbox.items[1].item)
        self.listbox.selected = 1
    end
    self:doSearch()
end

function ModOptionsScreen:createChildren()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.load then
        PZAPI.ModOptions:load()
    end
    
    local btnPadding = 32 + 10 * 2
    local btnWidthBack = btnPadding + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_back"))
    local btnWidthAccept = btnPadding + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_accept"))
    local btnWidthApply = btnPadding + getTextManager():MeasureStringX(UIFont.Small, getText("UI_btn_apply"))
    local totalBtnWidth = btnWidthBack + btnWidthAccept + btnWidthApply + 10 * 2
    local startX = (self.width - totalBtnWidth) / 2
    local buttonHgt = getTextManager():getFontHeight(UIFont.Small) + 6
    
    self.backButton = ISButton:new(startX, self.height - 10 - buttonHgt - 1, btnWidthBack, buttonHgt, getText("UI_btn_back"), self, self.onOptionMouseDown)
    self.backButton.internal = "BACK"
    self.backButton:initialise()
    self.backButton:instantiate()
    self.backButton:enableCancelColor()
    self:addChild(self.backButton)

    self.acceptButton = ISButton:new(self.backButton:getRight() + 10, self.backButton.y, btnWidthAccept, buttonHgt, getText("UI_btn_accept"), self, self.onOptionMouseDown)
    self.acceptButton.internal = "ACCEPT"
    self.acceptButton:initialise()
    self.acceptButton:instantiate()
    self.acceptButton:enableAcceptColor()
    self:addChild(self.acceptButton)

    self.applyButton = ISButton:new(self.acceptButton:getRight() + 10, self.backButton.y, btnWidthApply, buttonHgt, getText("UI_btn_apply"), self, self.onOptionMouseDown)
    self.applyButton.internal = "APPLY"
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self:addChild(self.applyButton)

    local listboxWidth = 200
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data then
        for _, options in ipairs(PZAPI.ModOptions.Data) do
            if options and options.name then
                local displayName = options.name and getText(options.name) or options.name
                local nameWidth = getTextManager():MeasureStringX(UIFont.Large, displayName)
                listboxWidth = math.max(nameWidth, listboxWidth)
            end
        end
    end
    listboxWidth = math.min(listboxWidth + 10 * 2, 300)

    local entryHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight() + 6
    local searchEntryY = 10 * 2 + getTextManager():getFontHeight(UIFont.Large) + 1

    self.sortCombo = ISComboBox:new(10 + 1, searchEntryY, listboxWidth, entryHgt, self, self.onSortChanged)
    self.sortCombo:initialise()
    self.sortCombo:addOptionWithData(getText("UI_modlistpanel_sortBy_name"), "name")
    self.sortCombo:addOptionWithData(getText("UI_modlistpanel_sortBy_date"), "date_added")
    self.sortCombo.selected = 1
    self:addChild(self.sortCombo)

    local searchX = self.sortCombo:getRight() + 10
    self.searchEntry = ISTextEntryBox:new("", searchX, searchEntryY, self.width - searchX - 10 - 1, entryHgt)
    self.searchEntry.font = UIFont.Medium
    self.searchEntry.onTextChange = function() self:doSearch() end
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    if SandboxOptionsScreen and SandboxOptionsScreen.searchPrerender then
        self.searchEntry.prerender = SandboxOptionsScreen.searchPrerender
    end
    self:addChild(self.searchEntry)

    local listY = self.searchEntry:getBottom() + 10
    local listHeight = self.height - listY - 10 * 2 - buttonHgt - 1
    self.listbox = ModOptionsScreenListBox:new(10 + 1, listY, listboxWidth, listHeight)
    self.listbox:initialise()
    self.listbox:setFont("Medium", 4)
    self.listbox.drawBorder = true
    self.listbox:setOnMouseDownFunction(self, self.onMouseDownListbox)
    self:addChild(self.listbox)

    self:sortAndRefillListbox()
    self:toUI()
end

function ModOptionsScreen:doSearch()
    if not self.searchEntry or not self.listbox then return end
    local searchWord = string.lower(self.searchEntry:getInternalText() or "")
    local firstMatchIndex = -1
    for i, item in ipairs(self.listbox.items) do
        item.searchFound = false
        if item.item.panel and item.item.panel.labels then
            local panelHasMatch = false
            if searchWord ~= "" then
                local modName = item.item.page.name and getText(item.item.page.name) or item.item.page.name or ""
                if string.find(string.lower(modName), searchWord, 1, true) then
                    panelHasMatch = true
                end
            end
            for settingName, label in pairs(item.item.panel.labels) do
                if label then
                    label.searchFound = false
                    if searchWord ~= "" then
                        local labelName = label:getName() or ""
                        if string.find(string.lower(labelName), searchWord, 1, true) then
                            label.searchFound = true
                            panelHasMatch = true
                        end
                        local modName = item.item.page.name and getText(item.item.page.name) or item.item.page.name or ""
                        if string.find(string.lower(modName), searchWord, 1, true) then
                            label.searchFound = true
                        end
                    end
                end
            end
            if panelHasMatch then
                item.searchFound = true
                if firstMatchIndex == -1 then
                    firstMatchIndex = i
                end
            end
        end
    end
    if firstMatchIndex ~= -1 and self.listbox.selected ~= firstMatchIndex then
        self.listbox.selected = firstMatchIndex
        self:onMouseDownListbox(self.listbox.items[firstMatchIndex].item)
    end
end

function ModOptionsScreen:createPanel(page)
    local panel = ModOptionsScreenPanel:new(self.listbox:getRight() + 10, self.listbox:getY(), self.width - self.listbox:getRight() - 10 * 2 - 1, self.listbox:getHeight())
    panel._instance = self
    panel:initialise()
    panel:instantiate()
    
    local addControlsTo = panel
    addControlsTo:setScrollChildren(true)
    addControlsTo:addScrollBars()
    addControlsTo.vscroll.doSetStencil = false

    local labels = {}
    local controls = {}
    
    for _, option in ipairs(page.data) do
        local label, control = self:createOptionControls(option, page)
        if label and control then
            if option.tooltip then
                local tooltipText = getText(option.tooltip)
                if tooltipText and string.trim(tooltipText) ~= "" then
                    control.tooltip = tooltipText
                    label.tooltip = tooltipText
                end
            end
            table.insert(labels, label)
            table.insert(controls, control)
        end
    end
    
    self:layoutControlsOnPanel(panel, addControlsTo, page, labels, controls)
    return panel
end

function ModOptionsScreen:createOptionControls(option, page)
    local entryHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight() + 6
    local buttonHgt = getTextManager():getFontHeight(UIFont.Small) + 6
    local controlWidth = 150 + ((getCore():getOptionFontSizeReal() - 1) * 50)
    
    if option.type == "title" or option.type == "separator" or option.type == "description" or option.type == "button" or option.type == "image" then
        return nil, nil
    end

    local label = ISLabel:new(0, 0, entryHgt, option.name and getText(option.name) or "", 1, 1, 1, 1, UIFont.Medium)
    local control = nil

    if option.type == "tickbox" then
        control = ISTickBox:new(0, 0, entryHgt, entryHgt, "")
        control:addOption("")
        local val = option.value
        if option.pendingValue ~= nil then val = option.pendingValue end
        control:setSelected(1, val)
        option.element = control
        control.changeOptionMethod = function(target, index, selected)
             option.pendingValue = selected
             self.optionsChanged = true
             if option.onChange then option.onChange(option, selected) end
        end
    elseif option.type == "multipletickbox" then
        control = ISTickBox:new(0, 0, buttonHgt, buttonHgt, "")
        if option.values then
            for i, value in ipairs(option.values) do
                control:addOption(value.name and getText(value.name) or "", value.name)
                local val = value.value
                if value.pendingValue ~= nil then val = value.pendingValue end
                control:setSelected(i, val)
            end
        end
        option.element = control
        control.changeOptionMethod = function(target, index, selected)
            if option.values and option.values[index] then
                option.values[index].pendingValue = selected
            end
            self.optionsChanged = true
            if option.onChange then option.onChange(option, index, selected) end
        end
    elseif option.type == "combobox" then
        control = ISComboBox:new(0, 0, controlWidth, entryHgt, self, nil)
        if option.values then
            for _, v in ipairs(option.values) do
                control:addOption(getText(v))
            end
        end
        control.selected = option.pendingValue or option.selected or 1
        option.element = control
        control.onChange = function(target, box)
            option.pendingValue = box.selected
            self.optionsChanged = true
            if option.onChange then option.onChange(option, box.selected) end
        end
    elseif option.type == "slider" then
        local container = ISPanel:new(0, 0, controlWidth * 2, entryHgt)
        container:noBackground()
        local val = option.pendingValue or option.value or option.min or 0
        local valueLabel = ISLabel:new(60, 0, entryHgt, tostring(val), 1, 1, 1, 1, UIFont.Small, false)
        valueLabel:initialise()
        container:addChild(valueLabel)
        control = ISSliderPanel:new(70, 0, controlWidth * 2 - 70, entryHgt, self, ModOptionsScreen.onSliderChange)
        control:setValues(option.min or 0, option.max or 100, option.step or 1, (option.step or 1) * 10)
        control:setCurrentValue(val)
        container:addChild(control)
        control.label = valueLabel
        control.container = container
        control.option = option
        option.element = control
    elseif option.type == "colorpicker" then
        if not option.modOptionsID then option.modOptionsID = page.modOptionsID end
        control = ISButton:new(0, 0, entryHgt * 2, entryHgt, "", self, self.onModColorPick)
        local initialColor = option.pendingColor or option.color or { r = 1, g = 1, b = 1, a = 1 }
        control.backgroundColor = { r = initialColor.r, g = initialColor.g, b = initialColor.b, a = initialColor.a }
        control.option = option
        control.colorPicker = ISColorPicker:new(0, 0)
        control.colorPicker:initialise()
        control.colorPicker.pickedTarget = self
        control.colorPicker.resetFocusTo = self
        control.colorPicker:setInitialColor(ColorInfo.new(initialColor.r, initialColor.g, initialColor.b, initialColor.a))
        option.element = control
    elseif option.type == "textentry" then
        control = ISTextEntryBox:new(option.pendingValue or option.value or "", 0, 0, controlWidth * 2, entryHgt)
        control.font = UIFont.Medium
        option.element = control
        control.onTextChange = function()
            option.pendingValue = control:getInternalText()
            self.optionsChanged = true
            if option.onChange then option.onChange(option, control:getInternalText()) end
        end
    elseif option.type == "keybind" then
        local val = option.pendingValue or option.value
        if val == nil then
            if option.key ~= nil then val = tostring(option.key)
            elseif option.defaultkey ~= nil then val = tostring(option.defaultkey); option.key = option.defaultkey end
        end
        local keyValue = tonumber(val) or 0
        local keyName = (keyValue > 0) and getKeyName(keyValue) or "None"
        control = ISButton:new(0, 0, controlWidth, entryHgt, keyName, self, MainOptions.onKeyBindingBtnPress)
        control.internal = option.name
        control.isModBind = true
        control.keyCode = keyValue
        option.element = control
    end
    return label, control
end

function ModOptionsScreen:addImageToPanel(addControlsTo, option, currentY, panelWidth, labelWidth, maxControlWidth)
    local texture = getTexture(option.path)
    if not texture then return currentY end
    local scrollbarWidth = addControlsTo.vscroll and addControlsTo.vscroll:getWidth() or 17
    local fullContentWidth = panelWidth - scrollbarWidth
    local imgWidth = texture:getWidthOrig()
    local imgHeight = texture:getHeightOrig()
    local finalWidth, finalHeight
    if option.fit then
        finalWidth = fullContentWidth - 20
        finalHeight = (imgHeight / imgWidth) * finalWidth
    else
        if option.minWidth then
            finalWidth = math.min(option.minWidth, fullContentWidth - 20)
            finalHeight = (imgHeight / imgWidth) * finalWidth
        else
            local controlsAreaWidth = labelWidth + maxControlWidth + 10
            finalWidth = imgWidth
            finalHeight = imgHeight
            if finalWidth > controlsAreaWidth then
                finalWidth = controlsAreaWidth
                finalHeight = (imgHeight / imgWidth) * finalWidth
            end
        end
    end
    local imageX = (fullContentWidth - finalWidth) / 2
    local image = ISImage:new(imageX, currentY, finalWidth, finalHeight, texture)
    image.autoScale = true
    image:initialise()
    addControlsTo:addChild(image)
    return currentY + finalHeight + 10
end

function ModOptionsScreen:layoutControlsOnPanel(panel, addControlsTo, page, labels, controls)
    local entryHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight() + 6
    local controlWidth = 150 + ((getCore():getOptionFontSizeReal() - 1) * 50)
    local labelWidth = 0
    for _, label in ipairs(labels) do
        if label then labelWidth = math.max(labelWidth, label:getWidth()) end
    end
    local maxControlWidth = 0
    for _, control in ipairs(controls) do
        if control then
            local width = control:getWidth()
            if control.Type == 'ISSliderPanel' and control.container then width = control.container:getWidth() end
            maxControlWidth = math.max(maxControlWidth, width)
        end
    end
    local xOffset = (panel.width - (labelWidth + maxControlWidth + 20)) / 2
    local currentY = 11
    local optionIndex = 0
    for i = 1, #page.data do
        local option = page.data[i]
        if option.type == "title" then
            local title = ISLabel:new(0, currentY + 10, entryHgt, option.name and getText(option.name) or "", 1, 1, 1, 1, UIFont.Large)
            title:initialise()
            addControlsTo:addChild(title)
            title:setX((panel.width - title:getWidth()) / 2)
            currentY = currentY + title:getHeight() + 20
        elseif option.type == "separator" then
            local hLine = ISPanel:new(10, currentY, panel.width - 20 - 13, 2)
            hLine:drawRect(0, 0, hLine.width, 1, 1.0, 0.5, 0.5, 0.5)
            addControlsTo:addChild(hLine)
            currentY = currentY + hLine:getHeight() + 10
        elseif option.type == "description" then
            local richText = ISRichTextPanel:new(xOffset, currentY, panel.width - xOffset * 2, 100)
            richText.background = false
            richText.autosetheight = true
            richText.marginLeft = 0
            richText:initialise()
            addControlsTo:addChild(richText)
            richText:setText("<RGB:0.8,0.8,0.8>" .. (option.text and getText(option.text) or ""))
            richText:paginate()
            richText.onMouseWheel = function(self, del) return false end
            currentY = currentY + richText:getHeight() + 10
        elseif option.type == "button" then
            local button = ISButton:new(0, currentY, controlWidth, entryHgt, option.name and getText(option.name) or "")
            button:initialise()
            addControlsTo:addChild(button)
            button:setX(xOffset + labelWidth + 10)
            if option.onclick and option.args then
                button:setOnClick(option.onclick, option.args[1], option.args[2], option.args[3], option.args[4])
            end
            if option.tooltip then
                local tooltipText = getText(option.tooltip)
                if tooltipText and string.trim(tooltipText) ~= "" then button:setTooltip(tooltipText) end
            end
            currentY = currentY + button:getHeight() + 10
        elseif option.type == "image" then
            currentY = self:addImageToPanel(addControlsTo, option, currentY, panel.width, labelWidth, maxControlWidth)
        else
            optionIndex = optionIndex + 1
            local label = labels[optionIndex]
            local control = controls[optionIndex]
            if label and control then
                addControlsTo:addChild(label)
                label:setX(xOffset)
                label:setY(currentY)
                if control.Type == 'ISSliderPanel' and control.container then
                    addControlsTo:addChild(control.container)
                    control.container:setX(xOffset + labelWidth + 10)
                    control.container:setY(currentY)
                else
                    addControlsTo:addChild(control)
                    control:setX(xOffset + labelWidth + 10)
                    control:setY(currentY)
                end
                currentY = currentY + math.max(label:getHeight(), control:getHeight()) + 10
            end
        end
    end
    addControlsTo:setScrollHeight(currentY)
    panel.labels = {}
    panel.controls = {}
    optionIndex = 0
    for i = 1, #page.data do
        local option = page.data[i]
        if option.type ~= "title" and option.type ~= "separator" and option.type ~= "description" and option.type ~= "button" and option.type ~= "image" then
            optionIndex = optionIndex + 1
            if labels[optionIndex] and controls[optionIndex] then
                panel.labels[option.id] = labels[optionIndex]
                panel.controls[option.id] = controls[optionIndex]
            end
        end
    end
end

function ModOptionsScreen:getModKeybind(keybindName)
    if not keybindName or not PZAPI or not PZAPI.ModOptions or not PZAPI.ModOptions.Data then return nil end
    for _, options in ipairs(PZAPI.ModOptions.Data) do
        if options and options.data then
            for _, option in ipairs(options.data) do
                if option.type == "keybind" and option.name == keybindName then return option end
            end
        end
    end
    return nil
end

function ModOptionsScreen:setModKeybind(keybindName, key)
    local keyBinded = self:getModKeybind(keybindName)
    if not keyBinded then return end

    keyBinded.pendingValue = tostring(key)

    if keyBinded.element then
        keyBinded.element.keyCode = key
        local keyNum = tonumber(key) or 0
        local keyName = (keyNum > 0) and getKeyName(keyNum) or "None"
        keyBinded.element:setTitle(keyName)
    end

    self.optionsChanged = true

    if MainOptions.setKeybindDialog then
        MainOptions.setKeybindDialog:destroy()
        MainOptions.setKeybindDialog = nil
    end
end

function ModOptionsScreen:showKeybindConflictDialog(key, keybindName, conflictingKeybindName)
    if MainOptions.setKeybindDialog then
        MainOptions.setKeybindDialog:destroy()
        MainOptions.setKeybindDialog = nil
    end
    local modal = ISDuplicateKeybindDialog:new(key, keybindName, conflictingKeybindName, false, false, false, function() self:setModKeybind(keybindName, key) end)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
end

function ModOptionsScreen:keyPressHandler(key, shift, ctrl, alt)
    if not MainOptions.setKeybindDialog or key <= 0 then
        if self.originalKeyPressHandler then self.originalKeyPressHandler(key, shift, ctrl, alt) end
        return
    end
    local keybindName = MainOptions.setKeybindDialog.keybindName
    if not self:getModKeybind(keybindName) then
        if self.originalKeyPressHandler then self.originalKeyPressHandler(key, shift, ctrl, alt) end
        return
    end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data then
        for _, options in ipairs(PZAPI.ModOptions.Data) do
            if options and options.data then
                for _, option in ipairs(options.data) do
                    if option.type == "keybind" and option.name ~= keybindName and (tonumber(option.pendingValue or option.value) or 0) == key then
                        self:showKeybindConflictDialog(key, keybindName, option.name)
                        return
                    end
                end
            end
        end
    end
    if MainOptions.keyText then
        for i, v in ipairs(MainOptions.keyText) do
            if not v.value and v.keyCode == key then
                self:showKeybindConflictDialog(key, keybindName, v.txt:getName())
                return
            end
        end
    end
    self:setModKeybind(keybindName, key)
end

function ModOptionsScreen:onModColorPick(button)
    if not button or not button.colorPicker then return end
    local x = self.x + button.parent.x + (button.parent:getXScroll() or 0) + button.x
    local y = self.y + button.parent.y + (button.parent:getYScroll() or 0) + button.y + button.height + 1
    if y + button.colorPicker.height > getCore():getScreenHeight() then
        y = y - button.height - button.colorPicker.height - 2
    end
    button.colorPicker:setX(x)
    button.colorPicker:setY(y)
    button.colorPicker.pickedFunc = function(target, color, mouseUp, ...)
        self:pickedModColor(target, color, mouseUp)
    end
    button.colorPicker.pickedTarget = button
    self:addChild(button.colorPicker)
    button.colorPicker:setVisible(true)
    button.colorPicker:bringToTop()
end

function ModOptionsScreen:onSliderChange(_value, _slider)
    if _slider.label then
        _slider.label:setName(tostring(_value))
    end
    if _slider.option then
        _slider.option.pendingValue = _value
    end
    self.optionsChanged = true
    if _slider.option and _slider.option.onChange then
        _slider.option.onChange(_slider.option, _value)
    end
end

function ModOptionsScreen:pickedModColor(button, color, mouseUp)
    if not button or not button.option or not color then return end
    button.backgroundColor = { r = color.r, g = color.g, b = color.b, a = 1 }
    button.option.pendingColor = button.backgroundColor
    self.optionsChanged = true
    if button.option.onChange then button.option.onChange(button.option, button.backgroundColor) end
end

function ModOptionsScreen:onMouseDownListbox(item)
    if not item or not item.page then return end
    if self.currentPanel then
        self:removeChild(self.currentPanel)
        self.currentPanel = nil
    end
    if item.panel then
        self:addChild(item.panel)
        self.currentPanel = item.panel
    end
end

function ModOptionsScreen:prerender()
    ISPanelJoypad.prerender(self)
    self:drawTextCentre(getText("UI_modoptions_title") or "Mod Options", self.width / 2, 11, 1, 1, 1, 1, UIFont.Title)
    if self.applyButton then
        self.applyButton:setEnable(self.optionsChanged or false)
    end
end

function ModOptionsScreen:onOptionMouseDown(button)
    if not button or not button.internal then return end
    if button.internal == "BACK" then
        self:close()
    elseif button.internal == "ACCEPT" then
        self:apply(true)
    elseif button.internal == "APPLY" then
        self:apply(false)
    end
end

function ModOptionsScreen:apply(closeAfter)
    if not PZAPI or not PZAPI.ModOptions then return end

    for _, options in ipairs(PZAPI.ModOptions.Data) do
        for _, option in ipairs(options.data) do
            if option.pendingValue ~= nil then
                option.value = option.pendingValue
                if option.type == "keybind" then
                    option.key = tonumber(option.pendingValue)
                end
                option.pendingValue = nil
            end
            if option.pendingColor ~= nil then
                option.color = option.pendingColor
                option.pendingColor = nil
            end
            
            if option.type == "multipletickbox" and option.values then
                for i, val in ipairs(option.values) do
                    if val.pendingValue ~= nil then
                        val.value = val.pendingValue
                        val.pendingValue = nil
                    end
                end
            end
            
            if option.element and option.type ~= "keybind" and option.type ~= "colorpicker" and option.type ~= "slider" then
                if option.type == "textentry" then
                     option.value = option.element:getInternalText()
                elseif option.type == "tickbox" then
                     option.value = option.element:isSelected(1)
                elseif option.type == "combobox" then
                    option.selected = option.element.selected
                end
            end
        end
    end
    
    PZAPI.ModOptions:save(); PZAPI.ModOptions:load()

    for _, options in ipairs(PZAPI.ModOptions.Data) do
        if options.apply then options:apply() end
    end

    self:toUI(); self.optionsChanged = false

    if closeAfter then self:close() end
end

function ModOptionsScreen:toUI()
    if not PZAPI or not PZAPI.ModOptions then return end
    for _, options in ipairs(PZAPI.ModOptions.Data) do
        for _, option in ipairs(options.data) do
            option.pendingValue = nil
            option.pendingColor = nil

            if option.element then
                if option.type == "textentry" then
                     option.element:setText(option.value or "")
                elseif option.type == "tickbox" then
                     option.element:setSelected(1, option.value or false)
                elseif option.type == "multipletickbox" and option.values then
                    for i = 1, #option.element.options do
                        if option.values[i] then
                            option.values[i].pendingValue = nil 
                            if option.values[i].value ~= nil then
                                option.element:setSelected(i, option.values[i].value)
                            end
                        end
                    end
                elseif option.type == "combobox" then
                    option.element.selected = option.selected or 1
                elseif option.type == "slider" then
                    local value = option.value or option.min or 0
                    option.element.label:setName(tostring(value))
                    option.element:setCurrentValue(value, true)
                elseif option.type == "colorpicker" then
                     if option.color then option.element.backgroundColor = option.color end
                elseif option.type == "keybind" then
                    local keyNum = tonumber(option.key or option.value) or 0
                    local keyName = (keyNum > 0) and getKeyName(keyNum) or "None"
                    option.element:setTitle(keyName)
                    option.element.keyCode = keyNum
                    option.value = tostring(keyNum)
                end
            end
        end
    end
    self.optionsChanged = false
end

function ModOptionsScreen:close()
    if self.originalKeyPressHandler then
        MainOptions.keyPressHandler = self.originalKeyPressHandler
        self.originalKeyPressHandler = nil
    end
    self:setVisible(false)
    if self.returnToUI then
        if self.returnToUI == MainScreen.instance then
            self.returnToUI.bottomPanel:setVisible(true, self.joyfocus)
        else
            self.returnToUI:setVisible(true, self.joyfocus)
        end
    elseif ModSelector and ModSelector.instance then
        ModSelector.instance:setVisible(true, self.joyfocus)
    end
    self:removeFromUIManager()
    ModOptionsScreen.instance = nil
end

function ModOptionsScreen:new(x, y, width, height)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.modsByDateAdded = {}
    return o
end

local original_onKeep = ISDuplicateKeybindDialog.onKeep
function ISDuplicateKeybindDialog:onKeep(...)
    original_onKeep(self, ...)
    if self.onKeepCallback then self:onKeepCallback() end
    self:destroy()
end

local original_onClear = ISDuplicateKeybindDialog.onClear
function ISDuplicateKeybindDialog:onClear(...)
    original_onClear(self, ...)
    if self.onKeepCallback then self:onKeepCallback() end
    self:destroy()
end

local original_new = ISDuplicateKeybindDialog.new
function ISDuplicateKeybindDialog:new(key, keybindName, keybind2Name, shift, ctrl, alt, onKeepCallback)
    local o = original_new(self, key, keybindName, keybind2Name, shift, ctrl, alt)
    o.onKeepCallback = onKeepCallback
    return o
end

local original_ISSetKeybindDialog_onClear = ISSetKeybindDialog.onClear
function ISSetKeybindDialog:onClear(...)
    if self.isModBind and ModOptionsScreen.instance then
        ModOptionsScreen.instance:setModKeybind(self.keybindName, 0)
        self:destroy()
        return
    end
    return original_ISSetKeybindDialog_onClear(self, ...)
end

local original_ISSetKeybindDialog_onDefault = ISSetKeybindDialog.onDefault
function ISSetKeybindDialog:onDefault(...)
    if self.isModBind and ModOptionsScreen.instance then
        local keyBinded = ModOptionsScreen.instance:getModKeybind(self.keybindName)
        if keyBinded and keyBinded.defaultkey then
            ModOptionsScreen.instance:setModKeybind(self.keybindName, keyBinded.defaultkey)
        else
            ModOptionsScreen.instance:setModKeybind(self.keybindName, 0)
        end
        self:destroy()
        return
    end
    return original_ISSetKeybindDialog_onDefault(self, ...)
end

Events.OnMainMenuEnter.Add(function()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.load then
        PZAPI.ModOptions:load()
    end
end)