-- --------------------------------------------------------------------------
-- NE_ViralStressHUD.lua (Build 42)
-- 変異度 (NE_MutationLevel) / ウイルスストレス HUD
-- 描画・スケール・計測: .cursor/registry/api_whitelist.md 準拠
-- --------------------------------------------------------------------------
--
-- 配色: getColorForMutation — 0% 水色 → 33% 青 → EVOLVED 手前まで濃い緑、NE.MUTATION_EVOLVED_THRESHOLD（既定 99.5）以上で赤
--   COL_CLEAN / COL_UNSTABLE / COL_DANGER / COL_EVOLVED
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

local COL_CLEAN    = { 0.4, 0.9, 1.0 } -- 0%: 水色
local COL_UNSTABLE = { 0.1, 0.4, 0.9 } -- 33%: 鮮やかな青
local COL_DANGER   = { 0.0, 0.4, 0.1 } -- 99.9%: 濃い緑
local COL_EVOLVED  = { 0.9, 0.1, 0.2 } -- EVOLVED 帯: 赤

--- NE_PlayerManager が設定する EVOLVED 境界（%）。未ロード時のみ 99.5。
---@return number
local function getNE_MutationEvolvedThreshold()
    local t = NE and NE.MUTATION_EVOLVED_THRESHOLD
    if type(t) == "number" and t == t then
        return t
    end
    return 99.5
end

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
    if pct >= getNE_MutationEvolvedThreshold() then
        return COL_EVOLVED[1], COL_EVOLVED[2], COL_EVOLVED[3]
    end
    pct = math.max(0, pct)
    local r, g, b
    if pct <= 33 then
        r, g, b = lerpColor3(COL_CLEAN, COL_UNSTABLE, pct / 33)
    else
        local span = 99.9 - 33
        local t = (pct - 33) / span
        t = math.max(0, math.min(1, t))
        r, g, b = lerpColor3(COL_UNSTABLE, COL_DANGER, t)
    end
    r = tonumber(r) or 0.5
    g = tonumber(g) or 0.5
    b = tonumber(b) or 0.5
    return r, g, b
end

--- チップ右の状態名。NE.GetMutationSpeechTier → NE.GetMutationSeverityText と健康パネルを同一経路にする。
---@param pct number
---@return string
local function getMutationStatusText(pct)
    pct = tonumber(pct) or 0
    pct = math.max(0, math.min(100, pct))
    if NE and NE.GetMutationSeverityText then
        local s = NE.GetMutationSeverityText(pct)
        if type(s) == "string" then
            return s
        end
    end
    if NE and NE.GetMutationSpeechTier then
        local tier = NE.GetMutationSpeechTier(pct)
        if type(tier) == "string" then
            local s2 = getText("UI_NE_Status_" .. tier)
            if type(s2) == "string" then
                return s2
            end
        end
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

    -- アイコンのみ: 彩度 100%〜50% 相当を L へのブレンドでパルス（バー・テキストは mr,mg,mb のまま）
    local L = 0.299 * mr + 0.587 * mg + 0.114 * mb
    local rwTime = getTimestampMs() / 1000.0
    local pulseAng = rwTime * (3 + pct / 20)
    local sFactor = 0.25 * (1 + math.sin(pulseAng))
    local ir = mr * (1 - sFactor) + L * sFactor
    local ig = mg * (1 - sFactor) + L * sFactor
    local ib = mb * (1 - sFactor) + L * sFactor

    -- 左→右: アイコン → バー → ％。ステータスは「チップ drawRect のみ」→ その後 drawText
    if tex and self.drawTextureScaled then
        self:drawTextureScaled(tex, iconX, iconY, iconS, iconS, 1, ir, ig, ib)
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
        -- 文字色を白 (1, 1, 1) に固定。背景チップ(drawRect)の色は mr, mg, mb のまま維持
        self:drawText(status, statusX, textY, 1, 1, 1, 1, font)
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
