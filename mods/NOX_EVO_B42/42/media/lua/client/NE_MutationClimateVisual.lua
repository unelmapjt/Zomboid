-- NE_MutationClimateVisual.lua — 変異度連動: ClimateManager 彩度 + ImprovedFog 視野制限（穴あき赤霧）+ 遠景霧色（画像不使用）

print(">>> [NE] CLIMATE FILTER SYSTEM ACTIVE")

NE = NE or {}

local function NE_ApplyMutationFilter()
    if NE.Switches and NE.Switches.EnableMutation == false then
        return
    end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() then
        return
    end

    if not player.getModData then
        return
    end
    local md = player:getModData()
    if not md then
        return
    end

    local mut = tonumber(md.NE_MutationLevel) or 0

    local cm = getClimateManager()
    if not cm or not cm.getClimateFloat or not cm.getClimateColor then
        return
    end

    if not ClimateManager or ClimateManager.FLOAT_DESATURATION == nil then
        return
    end

    local desat = cm:getClimateFloat(ClimateManager.FLOAT_DESATURATION)

    local fogCol = nil
    if ClimateManager.COLOR_NEW_FOG ~= nil then
        fogCol = cm:getClimateColor(ClimateManager.COLOR_NEW_FOG)
    end

    -- 変異度 50% 以上で発動
    if mut > 50 then
        local t = (mut - 50) / 50
        t = math.min(1.0, math.max(0.0, t))

        -- ① 彩度低下 (100% で完全白黒)
        if desat and desat.setEnableOverride and desat.setOverride then
            desat:setEnableOverride(true)
            desat:setOverride(t * 1.0, 1.0)
            if type(desat.interpolate) == "function" then
                desat:interpolate(1.0)
            end
        end

        -- ② ImprovedFog による視野制限（もやとプレイヤー周囲の穴）
        if ImprovedFog then
            if type(ImprovedFog.setEnableEditing) == "function" then
                ImprovedFog.setEnableEditing(true)
            end
            if type(ImprovedFog.setBaseAlpha) == "function" then
                ImprovedFog.setBaseAlpha(t * 0.5)
            end
            local radius = 10 - (t * 6)
            if type(ImprovedFog.setAlphaCircleRad) == "function" then
                ImprovedFog.setAlphaCircleRad(radius)
            end
            if type(ImprovedFog.setAlphaCircleAlpha) == "function" then
                ImprovedFog.setAlphaCircleAlpha(0.0)
            end
            local dls = 0.0
            if type(cm.getDayLightStrength) == "function" then
                dls = cm:getDayLightStrength() or 0.0
            end
            local brightness = 0.2 + (dls * 0.4)
            if type(ImprovedFog.setColorR) == "function" then
                ImprovedFog.setColorR(brightness)
            end
            if type(ImprovedFog.setColorG) == "function" then
                ImprovedFog.setColorG(0.0)
            end
            if type(ImprovedFog.setColorB) == "function" then
                ImprovedFog.setColorB(0.0)
            end
        end

        -- ③ 遠景用の霧色オーバーライド（赤）
        local dls2 = 0.0
        if type(cm.getDayLightStrength) == "function" then
            dls2 = cm:getDayLightStrength() or 0.0
        end
        local brightnessFog = 0.2 + (dls2 * 0.4)

        if fogCol and fogCol.setEnableOverride and fogCol.setOverride and ClimateColorInfo and type(ClimateColorInfo.new) == "function" then
            local col = ClimateColorInfo.new()
            if col and col.setExterior and col.setInterior then
                col:setExterior(brightnessFog, 0.0, 0.0, 1.0)
                col:setInterior(brightnessFog, 0.0, 0.0, 1.0)
                fogCol:setEnableOverride(true)
                fogCol:setOverride(col, 1.0)
            end
        end
    else
        -- 50% 未満ならすべて解除
        if desat and desat.setEnableOverride then
            desat:setEnableOverride(false)
        end

        if ImprovedFog and type(ImprovedFog.setEnableEditing) == "function" then
            ImprovedFog.setEnableEditing(false)
        end

        if fogCol and fogCol.setEnableOverride then
            fogCol:setEnableOverride(false)
        end
    end
end

if Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(NE_ApplyMutationFilter)
end
