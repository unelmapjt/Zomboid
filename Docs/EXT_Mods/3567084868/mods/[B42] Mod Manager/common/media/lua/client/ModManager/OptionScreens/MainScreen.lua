require "OptionScreens/MainScreen"
require "ModManager/ModOptions/ModOptionsScreen"

local original_instantiate = MainScreen.instantiate
function MainScreen:instantiate(...)
    original_instantiate(self, ...)

    if self.inGame and self.optionsOption and #PZAPI.ModOptions.Data > 0 then
        local labelHgt = self.optionsOption:getHeight()
        local labelX = self.optionsOption:getX()
        local labelSeparator = 16

        self.modOptionsOption = ISLabel:new(labelX, 0, labelHgt, getText("UI_mainscreen_btn_configs"), 1, 1, 1, 1, UIFont.Large, true)
        self.modOptionsOption.internal = "MODOPTIONS"
        self.modOptionsOption:initialise()
        self.modOptionsOption.onMouseDown = MainScreen.onMenuItemMouseDownMainMenu

        self.modOptionsOption.fade = UITransition.new()
        self.modOptionsOption.fade:setFadeIn(false)
        self.modOptionsOption.prerender = MainScreen.prerenderBottomPanelLabel

        self.bottomPanel:addChild(self.modOptionsOption)
        
        local yDelta = self.modOptionsOption:getHeight() + labelSeparator
        
        if self.sb_options then
            self.modOptionsOption:setY(self.optionsOption:getBottom() + labelSeparator)
            self.sb_options:setY(self.sb_options:getY() + yDelta)
            if self.exitOption then
                self.exitOption:setY(self.exitOption:getY() + yDelta)
            end
            if self.quitToDesktop then
                self.quitToDesktop:setY(self.quitToDesktop:getY() + yDelta)
            end
        else
            local newY = self.optionsOption:getBottom() + labelSeparator
            self.modOptionsOption:setY(newY)
            if self.exitOption then
                self.exitOption:setY(self.exitOption:getY() + yDelta)
            end
            if self.quitToDesktop then
                self.quitToDesktop:setY(self.quitToDesktop:getY() + yDelta)
            end
        end

        self.maxMenuItemWidth = math.max(self.maxMenuItemWidth, self.modOptionsOption:getWidth())
        for _, child in pairs(self.bottomPanel:getChildren()) do
            if child.Type == "ISLabel" then
                child:setWidth(self.maxMenuItemWidth)
            end
        end
        self.bottomPanel:setWidth(self.maxMenuItemWidth)
        self.bottomPanel:setHeight(self.bottomPanel:getHeight() + yDelta)

        if self.sb_options and self.sb_options.prerender ~= MainScreen.prerenderBottomPanelLabel then
            self.sb_options.fade = UITransition.new()
            self.sb_options.fade:setFadeIn(false)
            self.sb_options.prerender = MainScreen.prerenderBottomPanelLabel
            self.sb_options.setJoypadFocused = NewGameScreen.Label_setJoypadFocused
        end
    end
end

local original_render = MainScreen.render
function MainScreen:render(...)
    original_render(self, ...)

    if self.inGame and isClient() and self.modOptionsOption and self.modOptionsOption:isVisible() then
        local labelSeparator = 16
        
        local newY = self.optionsOption:getBottom()
        self.modOptionsOption:setY(newY)
        
        newY = self.modOptionsOption:getBottom() + labelSeparator

        if self.sb_options and self.sb_options:isVisible() then
            self.sb_options:setY(newY)
            newY = self.sb_options:getBottom() + labelSeparator
        end

        if self.exitOption then
            self.exitOption:setY(newY)
            newY = self.exitOption:getBottom()
        end

        if self.quitToDesktop then
            self.quitToDesktop:setY(newY)
            newY = self.quitToDesktop:getBottom()
        end

        self.bottomPanel:setHeight(newY)
    end
end

local original_onGainJoypadFocus = MainScreen.onGainJoypadFocus
function MainScreen:onGainJoypadFocus(...)
    original_onGainJoypadFocus(self, ...)
    if self.inGame and self.modOptionsOption then
        for i, buttons in ipairs(self.joypadButtonsY) do
            if buttons[1] == self.optionsOption then
                table.insert(self.joypadButtonsY, i + 1, { self.modOptionsOption })
                break
            end
        end
    end
end

local original_onMenuItemMouseDownMainMenu = MainScreen.onMenuItemMouseDownMainMenu
function MainScreen.onMenuItemMouseDownMainMenu(item, x, y)
    if item.internal == "MODOPTIONS" then
        getSoundManager():playUISound("UIActivateMainMenuItem")
        local joypadData = JoypadState.getMainMenuJoypad()
        
        MainScreen.instance.bottomPanel:setVisible(false)

        local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
        local width = screenW * 0.7
        local height = screenH * 0.8
        local x = (screenW - width) / 2
        local y = (screenH - height) / 2
        local modOptions = ModOptionsScreen:new(x, y, width, height)
        modOptions:initialise()
        modOptions:instantiate()
        MainScreen.instance:addChild(modOptions)
        modOptions:bringToTop()
        modOptions:setCapture(true)

        modOptions.returnToUI = MainScreen.instance
        modOptions:setVisible(true, joypadData)
        return
    end
    original_onMenuItemMouseDownMainMenu(item, x, y)
end