-- NOX: EVOLVED Pollution System
NE = NE or {}

--- プレイヤーの汚染状態を更新する (1分ごと)
---@param player IsoPlayer
---@param forceRecalc boolean 10タイル以上の移動があったか
function NE.UpdatePollution(player, forceRecalc)
    if not player or player:isDead() then return end

    local square = player:getCurrentSquare()
    if not square then return end

    local modData = player:getModData()

    -- 1. 座標ベースの汚染係数 (Viral Factor) の取得
    -- 10タイル以上移動していない場合は前回の値を再利用して負荷軽減
    local viralFactor = modData.NE_LastViralFactor or 0
    if forceRecalc or not modData.NE_LastViralFactor then
        viralFactor = NE.GetViralFactor(player:getX(), player:getY(), player:getZ())
        modData.NE_LastViralFactor = viralFactor
    end

    -- 2. 場所による倍率の判定
    local locMult = NE.Config.LocMult.GeneralIndoors
    if player:isOutside() then
        locMult = NE.Config.LocMult.Outdoor
    else
        local room = square:getRoom()
        if room then
            local roomDef = room:getRoomDef()
            if roomDef then
                local roomName = roomDef:getName() or ""
                -- 部屋名による施設判定（研究・軍事・実験室など）
                if string.find(roomName, "research") or 
                   string.find(roomName, "military") or 
                   string.find(roomName, "laboratory") or
                   string.find(roomName, "prison") then
                    locMult = NE.Config.LocMult.ResearchFacility
                end
            end
        end
    end

    -- 3. ガスマスク装備状態の判定
    local maskMult = NE.Config.MaskMult.NoMask
    local wornItems = player:getWornItems()
    local mask = nil

    if wornItems then
        for i = 0, wornItems:size() - 1 do
            local item = wornItems:get(i):getItem()
            if item:getBodyLocation() == "Mask" or item:getBodyLocation() == "FullHat" then
                mask = item
                break
            end
        end
    end

    if mask then
        if mask:getCondition() > 0 then
            maskMult = NE.Config.MaskMult.GoodMask
        else
            maskMult = NE.Config.MaskMult.BrokenMask
        end
    end

    -- 4. 環境判定 (霧の影響)
    local climateFog = 0.0
    if player:isOutside() then
        climateFog = getClimateManager():getFogIntensity()
    end

    -- 震源地からの距離による局所的なバイオ汚染 (バイオ霧)
    local bioFog = viralFactor

    -- 最終的な環境倍率: 1.0 (基準) + 天候霧 + バイオ霧
    local fogMult = 1.0 + climateFog + bioFog

    -- 5. 汚染の上昇/減少値を計算
    local increment = 0
    if viralFactor > 0 then
        -- 汚染圏内: 加算
        increment = NE.Config.BaseRate * locMult * maskMult * viralFactor * fogMult
    else
        -- 安全圏内: 減衰 (自然回復)
        local recovery = NE.Config.RecoveryRate
        
        -- 睡眠中は回復が 5倍に加速
        if player:isAsleep() then
            recovery = recovery * NE.Config.SleepMult
        end
        
        increment = recovery
    end

    -- 6. プレイヤーの ModData に加算
    modData.NE_PollutionLevel = (modData.NE_PollutionLevel or 0) + increment

    -- 上限(MaxPollution)および下限でクランプ
    if modData.NE_PollutionLevel > NE.Config.MaxPollution then
        modData.NE_PollutionLevel = NE.Config.MaxPollution
    elseif modData.NE_PollutionLevel < 0 then
        modData.NE_PollutionLevel = 0
    end
end
