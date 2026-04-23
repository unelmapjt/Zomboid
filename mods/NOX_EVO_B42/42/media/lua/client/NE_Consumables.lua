-- --------------------------------------------------------------------------
-- NE_Consumables.lua — 消耗アイテムのクライアント効果（摂取イベント）
-- --------------------------------------------------------------------------

NE = NE or {}

local ANTI_MUTANT_FULLTYPE = "NOX_EVO_B42.NE_AntiMutantDrug"

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

    local bd = character.getBodyDamage and character:getBodyDamage() or nil
    if bd and type(bd["getHealth"]) == "function" and type(bd["setHealth"]) == "function" then
        pcall(function()
            local curH = bd:getHealth()
            if curH == nil then
                return
            end
            local cap = 100.0
            if type(bd["getMaxHealth"]) == "function" then
                local mx = bd:getMaxHealth()
                if mx ~= nil and mx > 0 then
                    cap = mx
                end
            end
            ---@diagnostic disable-next-line: undefined-field
            bd:setHealth(math.max(1.0, curH - cap * 0.3))
        end)
    end

    local stats = character.getStats and character:getStats() or nil
    if stats and type(stats["setPanic"]) == "function" then
        pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            stats:setPanic(0.95)
        end)
    end

    if character.Say then
        character:Say(string.format("……効いている。変異度が %.0f 下がった。", sub))
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

--- Events.OnEat: (food, character) / (character, food) の順差を吸収
---@param first unknown
---@param second unknown
local function onEat(first, second)
    if not first or not second then
        return
    end
    local food, ch
    if type(first.getFullType) == "function" and type(second.getModData) == "function" then
        food, ch = first, second
    elseif type(second.getFullType) == "function" and type(first.getModData) == "function" then
        food, ch = second, first
    else
        return
    end
    local ft = food.getFullType and food:getFullType() or nil
    if ft ~= ANTI_MUTANT_FULLTYPE then
        return
    end
    applyAntiMutantDrug(ch)
end

-- B42 では `Events.OnEat` が無い環境がある。`OnEatFood` を優先して登録する。
local hookUsed = "none"
if Events.OnEatFood and Events.OnEatFood.Add then
    Events.OnEatFood.Add(onEat)
    hookUsed = "OnEatFood"
elseif Events.OnEat and Events.OnEat.Add then
    Events.OnEat.Add(onEat)
    hookUsed = "OnEat"
end

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace(
        "NE_INIT",
        "Consumables",
        "Load:OK|eatHook=" .. hookUsed,
        "INFO"
    )
end
