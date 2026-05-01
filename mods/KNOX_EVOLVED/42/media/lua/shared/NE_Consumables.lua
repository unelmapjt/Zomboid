-- --------------------------------------------------------------------------
-- NE_Consumables.lua — 消耗アイテム（アイテム定義の OnEat コールバック経由）
-- B42: NE_Items.txt の OnEat = NE_OnEat* がグローバル関数を直接呼ぶ（KnoxDrugs 方式）
-- --------------------------------------------------------------------------

NE = NE or {}

---@param character IsoGameCharacter
local function applyAntiMutantDrug(character)
    if not character or (character.isDead and character:isDead()) then
        return
    end
    local md = character.getModData and character:getModData() or nil
    if not md then
        return
    end

    local cur = md.NE_MutationLevel or 0
    local sub = 40 + ZombRand(21)
    md.NE_MutationLevel = math.max(0.0, cur - sub)

    -- B42実証済み方式（KnoxDrugs準拠）: CharacterStat で副作用を表現
    local CS = rawget(_G, "CharacterStat")
    local stats = character.getStats and character:getStats() or nil
    if stats and CS then
        -- 劇薬の副作用: 食物酔い（FOOD_SICKNESS）を大幅に引き上げて擬似的なダメージを表現
        if CS.FOOD_SICKNESS and type(stats.set) == "function" and type(stats.get) == "function" then
            pcall(function()
                local cur = stats:get(CS.FOOD_SICKNESS)
                local add = 30 + ZombRand(21) -- 30〜50 をランダムで加算
                local newFood = math.min(100, (cur or 0) + add)
                stats:set(CS.FOOD_SICKNESS, newFood)
                -- 固定60ではなく、実際に加算した値を保存する
                md.NE_DrugSideEffectFood = newFood
            end)
            -- 副作用タイマー: ゲーム内 10 分間は薬の FOOD_SICKNESS を保護する
            local gt2 = getGameTime and getGameTime() or nil
            if gt2 and gt2.getWorldAgeHours then
                local okN2, w2 = pcall(function()
                    return gt2:getWorldAgeHours() * 60
                end)
                if okN2 and type(w2) == "number" then
                    md.NE_DrugSideEffectEndTime = w2 + 10.0
                end
            end
        end
        -- パニックも同時に付与
        if CS.PANIC and type(stats.set) == "function" then
            pcall(function()
                stats:set(CS.PANIC, 0.95)
            end)
        end
    end

    if type(character.Say) == "function" then
        pcall(function()
            character:Say(getText("IGUI_NE_Antimutagen_Success", math.floor(sub)))
        end)
    end

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace(
            "NE_ITEM",
            "AntiMutantDrug",
            "Used|sub=" .. tostring(sub) .. "|level=" .. tostring(md.NE_MutationLevel),
            "INFO"
        )
    end
end

--- 汚染遅延薬: 30 分（ゲーム内分）変異度の増減を停止（NE_Mutation / HUD が NE_RetardantEndTime を参照）
---@param character IsoGameCharacter
local function applyRetardant(character)
    if not character or (character.isDead and character:isDead()) then
        return
    end
    local md = character.getModData and character:getModData() or nil
    if not md then
        return
    end
    local now = 0.0
    local gt = getGameTime and getGameTime() or nil
    if gt and gt.getWorldAgeHours then
        local okN, w = pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            return gt:getWorldAgeHours() * 60
        end)
        if okN and type(w) == "number" then
            now = w
        end
    end
    md.NE_RetardantEndTime = now + 30.0
    if type(character.Say) == "function" then
        pcall(function()
            character:Say(getText("IGUI_NE_Retardant_Success"))
        end)
    end
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace(
            "NE_ITEM",
            "Retardant",
            "Used|endTime=" .. tostring(md.NE_RetardantEndTime),
            "INFO"
        )
    end
end

--- スクリプト OnEat = から呼ばれる（引数: food, character, percent）
---@param food unknown
---@param character IsoGameCharacter|nil
---@param percent number|nil
function NE_OnEatAntiMutantDrug(food, character, percent)
    if not character then
        return
    end
    applyAntiMutantDrug(character)
end

---@param food unknown
---@param character IsoGameCharacter|nil
---@param percent number|nil
function NE_OnEatRetardant(food, character, percent)
    if not character then
        return
    end
    applyRetardant(character)
end
