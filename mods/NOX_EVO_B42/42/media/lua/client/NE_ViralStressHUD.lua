-- --------------------------------------------------------------------------
-- NE_ViralStressHUD.lua (Build 42)
-- 変異度 (NE_MutationLevel) / ウイルスストレス HUD
-- 描画・スケール・計測: .cursor/registry/api_whitelist.md 準拠
-- --------------------------------------------------------------------------
--
-- 配色物理定数（0% 水色 → 100% 毒赤、getColorForMutation で補間）
--   A 0%:   r=0.4, g=0.9, b=1.0
--   B 33%:  r=0.1, g=0.3, b=0.9
--   C 66%:  r=0.0, g=0.8, b=0.7
--   D 100%: r=0.9, g=0.1, b=0.2
-- バー塗り・ステータスチップは同一 (mr,mg,mb)。チップのみアルファを下げる。
-- 変異に伴う視覚演出（彩度・ImprovedFog・赤霧）: NE_MutationClimateVisual.lua。
--
-- --------------------------------------------------------------------------

require "ISUI/ISPanel"

NE = NE or {}

NE_ViralStressHUD = ISPanel:derive("NE_ViralStressHUD")

local BASE_PANEL_H = 40
local BASE_PAD = 4
local BASE_ICON_S = 28
local BASE_BAR_H = 6
local BASE_BAR_TRACK_W = 140
local BASE_GAP = 10
local BASE_CHIP_PAD_H = 6

-- チップ縦余白: fontH は既に解像度適用済みのため、ここでは self.scale を掛けない（二重スケール防止）
local CHIP_PAD_V_TOTAL_PX = 4

local BAR_TRACK_ALPHA = 0.35
local BAR_FILL_ALPHA = 0.92
local CHIP_BG_ALPHA = 0.3

local ICON_TEXTURE_PATH = "media/ui/NE_MutationIcon.png"

-- HUD 下端からのオフセット（従来の「下から約 150px」配置）
local HUD_BOTTOM_OFFSET_PX = 150

local COL_CLEAN = { 0.4, 0.9, 1.0 }    -- Light Blue (0%)
local COL_UNSTABLE = { 0.1, 0.3, 0.9 } -- Blue (25%)
local COL_DANGER = { 0.0, 0.4, 0.1 }   -- Dark Green (50%)
local COL_CRITICAL = { 0.9, 0.1, 0.2 } -- Red (75%)
local COL_EVOLVED = { 0.9, 0.1, 0.2 }  -- Red (100%)

---@param a number[]
---@param b number[]
---@param t number
---@return number, number, number
local function lerpColor3(a, b, t)
    t = math.max(0, math.min(1, t))
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

---@param pct number
---@return number, number, number
local function getColorForMutation(pct)
    pct = tonumber(pct) or 0
    pct = math.max(0, math.min(100, pct))
    local r, g, b
    if pct <= 25 then
        r, g, b = lerpColor3(COL_CLEAN, COL_UNSTABLE, pct / 25)
    elseif pct <= 50 then
        r, g, b = lerpColor3(COL_UNSTABLE, COL_DANGER, (pct - 25) / 25)
    elseif pct <= 75 then
        r, g, b = lerpColor3(COL_DANGER, COL_CRITICAL, (pct - 50) / 25)
    else
        r, g, b = lerpColor3(COL_CRITICAL, COL_EVOLVED, (pct - 75) / 25)
    end
    r = tonumber(r) or 0.5
    g = tonumber(g) or 0.5
    b = tonumber(b) or 0.5
    return r, g, b
end

--- チップに表示する状態名（閾値）。配色は getColorForMutation(pct) が pct 連続値で担当。
---@param pct number
---@return string
local function getMutationStatusText(pct)
    pct = tonumber(pct) or 0
    pct = math.max(0, math.min(100, pct))
    local key
    if pct >= 100 then
        key = "UI_NE_Status_EVOLVED"
    elseif pct >= 75 then
        key = "UI_NE_Status_Critical"
    elseif pct >= 50 then
        key = "UI_NE_Status_Danger"
    elseif pct >= 25 then
        key = "UI_NE_Status_Unstable"
    else
        key = "UI_NE_Status_Clean"
    end
    local s = getText(key)
    if type(s) == "string" then
        return s
    end
    return ""
end

function NE_ViralStressHUD:render()
    ISPanel.render(self)
end

---@param playerNum integer
---@return NE_ViralStressHUD
function NE_ViralStressHUD:new(playerNum)
    -- ヒット領域を過大にしない（実寸は prerender で totalW に合わせて更新）
    local o = ISPanel.new(self, 0, 0, 400, 50)
    o.playerNum = playerNum or 0
    o.moving = false
    o.hasUserMoved = false
    o._lastHasUserMoved = false
    o.layoutDirty = true
    o.iconTexture = nil
    o.iconResolved = false
    o.hudFont = UIFont.Medium
    o:initialise()
    o:setVisible(true)
    return o
end

function NE_ViralStressHUD:refreshLayoutMetricsFromCore()
    self.scale = getCore():getScreenHeight() / 1080
    self.pad = BASE_PAD * self.scale
    self.iconS = BASE_ICON_S * self.scale
    self.barH = BASE_BAR_H * self.scale
    self.barTrackW = BASE_BAR_TRACK_W * self.scale
    self.gap = BASE_GAP * self.scale
    self.height = BASE_PANEL_H * self.scale
    self.height = math.max(self.height, 50 * self.scale)
end

function NE_ViralStressHUD:initialise()
    ISPanel.initialise(self)
    self:noBackground()
    self:refreshLayoutMetricsFromCore()
    self.width = 400 * self.scale
end

--- 下端中央（ユーザーが手動で動かしていないときのみ）
function NE_ViralStressHUD:applyDefaultBottomLayout()
    if self.hasUserMoved then
        return
    end
    local pw = tonumber(getPlayerScreenWidth(self.playerNum)) or 0
    local ph = tonumber(getPlayerScreenHeight(self.playerNum)) or 0
    local scale = tonumber(self.scale) or 1
    local h = tonumber(self.height) or (50 * scale)
    local w = tonumber(self.width) or (400 * scale)
    local refH = 1080
    if ph <= 0 then
        ph = refH
    end
    local bottomPad = math.floor(HUD_BOTTOM_OFFSET_PX * (ph / refH))
    local yPos = ph - h - bottomPad
    self:setX((pw - w) / 2)
    self:setY(math.max(0, yPos))
end

function NE_ViralStressHUD:onResolutionChange()
    self:refreshLayoutMetricsFromCore()
    self.layoutDirty = true
end

function NE_ViralStressHUD:onMouseDown(x, y)
    self.moving = true
    return true
end

function NE_ViralStressHUD:onMouseMove(dx, dy)
    if not self.moving then
        return false
    end
    if dx ~= 0 or dy ~= 0 then
        self.hasUserMoved = true
    end
    self:setX(self:getX() + dx)
    self:setY(self:getY() + dy)
    return true
end

function NE_ViralStressHUD:onMouseMoveOutside(dx, dy)
    if not self.moving then
        return false
    end
    if dx ~= 0 or dy ~= 0 then
        self.hasUserMoved = true
    end
    self:setX(self:getX() + dx)
    self:setY(self:getY() + dy)
    return true
end

function NE_ViralStressHUD:onMouseUp(x, y)
    if not self.moving then
        return false
    end
    self.moving = false
    return false
end

function NE_ViralStressHUD:prerender()
    if not self.iconResolved then
        self.iconResolved = true
        if getTexture then
            self.iconTexture = getTexture(ICON_TEXTURE_PATH)
        end
    end

    local player = getSpecificPlayer(self.playerNum)
    local pct = 0
    if player and player.getModData then
        local md = player:getModData()
        if md then
            local v = md.NE_MutationLevel
            pct = tonumber(v) or 0
        end
    end
    pct = math.max(0, math.min(100, tonumber(pct) or 0))
    -- 表示は小数第2位まで。ステータス帯は生値で判定（ロジックの閾値と一致）
    local status = getMutationStatusText(pct)
    if type(status) ~= "string" then
        status = ""
    end
    local pctStr = string.format("%.2f%%", pct)
    if type(pctStr) ~= "string" then
        pctStr = "0.00%"
    end

    local tm = getTextManager()
    if not tm then
        return
    end
    local font = self.hudFont or UIFont.Medium
    local fontH = tm:getFontHeight(font)
    if type(fontH) ~= "number" or fontH ~= fontH then
        fontH = 12
    end
    local chipH = fontH + CHIP_PAD_V_TOTAL_PX
    if type(chipH) ~= "number" or chipH ~= chipH then
        chipH = fontH + 4
    end

    local scale = tonumber(self.scale)
    if not scale or scale <= 0 or scale ~= scale then
        scale = 1
        self.scale = scale
    end

    local wPct = tm:MeasureStringX(font, pctStr)
    local wStatus = tm:MeasureStringX(font, status)
    local wMissingIcon = tm:MeasureStringX(font, "Missing Icon")
    wPct = tonumber(wPct) or 0
    wStatus = tonumber(wStatus) or 0
    wMissingIcon = tonumber(wMissingIcon) or 0

    local chipPadH = BASE_CHIP_PAD_H * scale
    local statusColW = wStatus + 2 * chipPadH

    local pad = tonumber(self.pad) or (BASE_PAD * scale)
    local gap = tonumber(self.gap) or (BASE_GAP * scale)
    local barTrackW = tonumber(self.barTrackW) or (BASE_BAR_TRACK_W * scale)
    local barH = tonumber(self.barH) or (BASE_BAR_H * scale)
    local iconS = tonumber(self.iconS) or (BASE_ICON_S * scale)

    local iconColW = iconS
    local tex = self.iconTexture
    if not tex then
        iconColW = math.max(iconS, wMissingIcon)
    end

    local totalW = pad
        + iconColW
        + gap
        + barTrackW
        + gap
        + wPct
        + gap
        + statusColW
        + pad

    if type(totalW) ~= "number" or totalW ~= totalW then
        totalW = 400 * scale
    end

    self.width = totalW
    self.height = math.max(BASE_PANEL_H * scale, chipH + 2 * pad)

    if self.hasUserMoved ~= self._lastHasUserMoved then
        self._lastHasUserMoved = self.hasUserMoved
        if not self.hasUserMoved then
            self.layoutDirty = true
        end
    end

    if not self.hasUserMoved and self.layoutDirty then
        self:applyDefaultBottomLayout()
        self.layoutDirty = false
    end

    -- パネル縦中央を基準（相対 0）。各要素の上端 y = centerY - height/2
    local centerY = (tonumber(self.height) or 40) * 0.5
    ---@param h number 要素の高さ（ピクセル）
    ---@return number
    local function yTopFromCenter(h)
        return centerY - h * 0.5
    end

    local iconX = pad
    local barX = iconX + iconColW + gap
    local pctX = barX + barTrackW + gap
    local chipX = pctX + wPct + gap
    local statusX = chipX + chipPadH

    local iconY = yTopFromCenter(iconS)
    local barY = yTopFromCenter(barH)
    local chipY = yTopFromCenter(chipH)
    local textY = yTopFromCenter(fontH)

    local mr, mg, mb = getColorForMutation(pct)
    mr = tonumber(mr) or 0.5
    mg = tonumber(mg) or 0.5
    mb = tonumber(mb) or 0.5

    -- 左→右: アイコン → バー → ％。ステータスは「チップ drawRect のみ」→ その後 drawText
    if tex and self.drawTextureScaled then
        self:drawTextureScaled(tex, iconX, iconY, iconS, iconS, 1, mr, mg, mb)
    elseif self.drawText then
        self:drawText("Missing Icon", iconX, textY, 0.85, 0.85, 0.85, 1, font)
    end

    if self.drawRect then
        self:drawRect(barX, barY, barTrackW, barH, BAR_TRACK_ALPHA, 0.12, 0.12, 0.12)
        local fillW = barTrackW * ((tonumber(pct) or 0) / 100)
        if fillW == fillW and fillW > 0 then
            self:drawRect(barX, barY, fillW, barH, BAR_FILL_ALPHA, mr, mg, mb)
        end
    end

    if self.drawText then
        self:drawText(pctStr, pctX, textY, 1, 1, 1, 1, font)
    end

    local chipW = wStatus + 2 * chipPadH
    if chipW == chipW and chipW > 0 and self.drawRect then
        self:drawRect(chipX, chipY, chipW, chipH, CHIP_BG_ALPHA, mr, mg, mb)
    end
    if self.drawText and status ~= "" then
        self:drawText(status, statusX, textY, mr, mg, mb, 1, font)
    end
end

NE.ViralStressHUD = NE_ViralStressHUD

local NE_ResolutionHookAdded = false

local function NE_CreateViralStressHud()
    if NE.ViralStressHUDInstance then
        return
    end
    NE.ViralStressHUDInstance = NE_ViralStressHUD:new(0)
    NE.ViralStressHUDInstance:addToUIManager()
    if not NE_ResolutionHookAdded and Events.OnResolutionChange and Events.OnResolutionChange.Add then
        NE_ResolutionHookAdded = true
        Events.OnResolutionChange.Add(function()
            local hud = NE.ViralStressHUDInstance
            if hud and hud.refreshLayoutMetricsFromCore then
                hud:refreshLayoutMetricsFromCore()
                hud.layoutDirty = true
            end
        end)
    end
end

Events.OnGameStart.Add(NE_CreateViralStressHud)
