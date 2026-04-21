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

local ICON_TEXTURE_PATH = "media/ui/Heart_OnFull.png"

local COL_A = { 0.4, 0.9, 1.0 }
local COL_B = { 0.1, 0.3, 0.9 }
local COL_C = { 0.0, 0.8, 0.7 }
local COL_D = { 0.9, 0.1, 0.2 }

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
    pct = math.max(0, math.min(100, pct))
    if pct <= 33 then
        return lerpColor3(COL_A, COL_B, pct / 33)
    end
    if pct <= 66 then
        return lerpColor3(COL_B, COL_C, (pct - 33) / (66 - 33))
    end
    return lerpColor3(COL_C, COL_D, (pct - 66) / (100 - 66))
end

--- チップに表示する状態名（閾値）。配色は getColorForMutation(pct) が pct 連続値で担当。
---@param pct number
---@return string
local function getMutationStatusText(pct)
    pct = math.max(0, math.min(100, pct))
    local key
    if pct >= 100 then
        key = "UI_NE_Status_EVOLVED"
    elseif pct >= 75 then
        key = "UI_NE_Status_Critical"
    elseif pct >= 50 then
        key = "UI_NE_Status_Danger"
    elseif pct >= 25 then
        key = "UI_NE_Status_UnStable"
    else
        key = "UI_NE_Status_Clean"
    end
    return getText(key)
end

---@param playerNum integer
---@return NE_ViralStressHUD
function NE_ViralStressHUD:new(playerNum)
    local o = ISPanel.new(self, 0, 0, 800, 100)
    o.playerNum = playerNum or 0
    o.moving = false
    o.hasUserMoved = false
    o.iconTexture = nil
    o.iconResolved = false
    o.hudFont = UIFont.Medium
    o:initialise()
    o:setVisible(true)
    return o
end

function NE_ViralStressHUD:initialise()
    ISPanel.initialise(self)
    self:noBackground()
    self.scale = getCore():getScreenHeight() / 1080
    self.pad = BASE_PAD * self.scale
    self.iconS = BASE_ICON_S * self.scale
    self.barH = BASE_BAR_H * self.scale
    self.barTrackW = BASE_BAR_TRACK_W * self.scale
    self.gap = BASE_GAP * self.scale
    self.height = BASE_PANEL_H * self.scale
end

function NE_ViralStressHUD:onMouseDown(x, y)
    self.moving = true
    return true
end

function NE_ViralStressHUD:onMouseMove(dx, dy)
    if self.moving then
        if dx ~= 0 or dy ~= 0 then
            self.hasUserMoved = true
        end
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function NE_ViralStressHUD:onMouseMoveOutside(dx, dy)
    if self.moving then
        if dx ~= 0 or dy ~= 0 then
            self.hasUserMoved = true
        end
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function NE_ViralStressHUD:onMouseUp(x, y)
    self.moving = false
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
            if v == nil or v < 1.0 then
                md.NE_MutationLevel = 20.0
                md.NE_MutationBootstrapDone = true
                pct = 20.0
                if Z_TRACER and Z_TRACER.EmitTrace then
                    Z_TRACER.EmitTrace(
                        "NE_MUTATION",
                        "HUDRepair",
                        "AutoFix|level=20.0|reason=nil_or_below_1",
                        "INFO"
                    )
                end
            else
                pct = v
            end
        end
    end
    pct = math.max(0, math.min(100, pct))
    local pctDisp = math.floor(pct + 0.5)
    local status = getMutationStatusText(pct)
    local pctStr = tostring(pctDisp) .. "%"

    local tm = getTextManager()
    local font = self.hudFont
    local fontH = tm:getFontHeight(font)
    local chipH = fontH + CHIP_PAD_V_TOTAL_PX

    local wPct = tm:MeasureStringX(font, pctStr)
    local wStatus = tm:MeasureStringX(font, status)
    local wMissingIcon = tm:MeasureStringX(font, "Missing Icon")

    local chipPadH = BASE_CHIP_PAD_H * self.scale
    local statusColW = wStatus + 2 * chipPadH

    local iconColW = self.iconS
    if not self.iconTexture then
        iconColW = math.max(self.iconS, wMissingIcon)
    end

    local totalW = self.pad
        + iconColW
        + self.gap
        + self.barTrackW
        + self.gap
        + wPct
        + self.gap
        + statusColW
        + self.pad

    self.width = totalW

    -- パネル縦中央を基準（相対 0）。各要素の上端 y = centerY - height/2
    local centerY = self.height * 0.5
    ---@param h number 要素の高さ（ピクセル）
    ---@return number
    local function yTopFromCenter(h)
        return centerY - h * 0.5
    end

    local iconX = self.pad
    local barX = iconX + iconColW + self.gap
    local pctX = barX + self.barTrackW + self.gap
    local chipX = pctX + wPct + self.gap
    local statusX = chipX + chipPadH

    local iconY = yTopFromCenter(self.iconS)
    local barY = yTopFromCenter(self.barH)
    local chipY = yTopFromCenter(chipH)
    local textY = yTopFromCenter(fontH)

    if not self.hasUserMoved then
        local pw = getPlayerScreenWidth(self.playerNum)
        local yPos = getPlayerScreenHeight(self.playerNum) - 150
        if player and player.inventoryHotbar and player.inventoryHotbar.y then
            yPos = player.inventoryHotbar.y - self.height - 10
        end
        yPos = yPos - 20
        self:setX((pw - self.width) / 2)
        self:setY(yPos)
    end

    local mr, mg, mb = getColorForMutation(pct)

    -- 左→右: アイコン → バー → ％。ステータスは「チップ drawRect のみ」→ その後 drawText
    if self.iconTexture then
        self:drawTextureScaled(self.iconTexture, iconX, iconY, self.iconS, self.iconS, 1, 1, 1, 1)
    else
        self:drawText("Missing Icon", iconX, textY, 0.85, 0.85, 0.85, 1, font)
    end

    self:drawRect(barX, barY, self.barTrackW, self.barH, BAR_TRACK_ALPHA, 0.12, 0.12, 0.12)
    local fillW = self.barTrackW * (pct / 100)
    self:drawRect(barX, barY, fillW, self.barH, BAR_FILL_ALPHA, mr, mg, mb)

    self:drawText(pctStr, pctX, textY, 1, 1, 1, 1, font)

    self:drawRect(chipX, chipY, wStatus + 2 * chipPadH, chipH, CHIP_BG_ALPHA, mr, mg, mb)
    self:drawText(status, statusX, textY, mr, mg, mb, 1, font)
end

NE.ViralStressHUD = NE_ViralStressHUD

local function NE_CreateViralStressHud()
    if NE.ViralStressHUDInstance then
        return
    end
    NE.ViralStressHUDInstance = NE_ViralStressHUD:new(0)
    NE.ViralStressHUDInstance:addToUIManager()
end

Events.OnGameStart.Add(NE_CreateViralStressHud)
