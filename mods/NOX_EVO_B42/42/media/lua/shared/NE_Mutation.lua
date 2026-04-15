-- --------------------------------------------------------------------------
-- NE_Mutation.lua
-- Role: プレイヤーの変異度 (NE_MutationLevel) 更新ロジック
-- 設計書 4.11: DeltaMutation = BaseRate × LocMult × MaskMult × PhaseMult × FogMult × ZoneMultiplier
--
-- ■ Delta=1.5 検証 (Zone3 / 屋外 / マスクなし / Phase1 / 霧なし):
--   0.5(Base) × 1.0(Open) × 3.0(NoMask) × 1.0(Phase1) × 1.0(NoFog) × 1.0(Zone3) = 1.5 ✓
-- --------------------------------------------------------------------------

NE = NE or {}

--- プレイヤーの変異度 (NE_MutationLevel) を 1分ごとに更新する
--- NE_PlayerManager.lua (client) の EveryOneMinute から呼ばれる
---@param player IsoPlayer
---@param forceRecalc boolean 10タイル以上の移動または日付変更があったとき true
function NE.UpdateMutation(player, forceRecalc)
    if not player or player:isDead() then return end
    if NE.Switches and NE.Switches.EnableMutation == false then return end

    local square = player:getCurrentSquare()
    if not square then return end

    local modData = player:getModData()

    -- 1. ZoneMultiplier: プレイヤー個別キャッシュで負荷軽減 (設計書 4.4 / 4.8)
    local zoneMult = modData.NE_LastZoneMult
    if forceRecalc or zoneMult == nil then
        zoneMult = NE.GetZoneMultiplier(player:getX(), player:getY(), player:getZ())
        modData.NE_LastZoneMult = zoneMult
    end

    -- 2. LocMult: 室内密閉度 (設計書 4.7)
    --    Open=1.0(屋外) / Partial=0.7(一般室内) / Sealed=0.3(密閉施設)
    local locMult = NE.Config.LocMult.Partial
    if player:isOutside() then
        locMult = NE.Config.LocMult.Open
    else
        local vehicle = player:getVehicle()
        if vehicle then
            locMult = NE.Config.LocMult.Sealed
        else
            local room = square:getRoom()
            if room then
                local roomDef = room:getRoomDef()
                if roomDef then
                    local roomName = string.lower(roomDef:getName() or "")
                    if string.find(roomName, "research")   or
                       string.find(roomName, "military")   or
                       string.find(roomName, "laboratory") or
                       string.find(roomName, "prison") then
                        locMult = NE.Config.LocMult.Sealed
                    end
                end
            end
        end
    end

    -- 3. MaskMult: ガスマスク防護性能 (設計書 4.10)
    local maskMult  = NE.Config.MaskMult.NoMask
    local wornItems = player:getWornItems()
    if wornItems then
        for i = 0, wornItems:size() - 1 do
            local wi = wornItems:get(i)
            if wi then
                local item = wi:getItem()
                if item then
                    local loc = item:getBodyLocation()
                    if loc == "Mask" or loc == "FullHat" then
                        maskMult = (item:getCondition() > 0)
                            and NE.Config.MaskMult.GoodMask
                            or  NE.Config.MaskMult.BrokenMask
                        break
                    end
                end
            end
        end
    end

    -- 4. PhaseMult: 世界の侵食段階 (設計書 11.1)
    --    Phase1(Day1-15)=1.0 / Phase2(Day16-35)=1.5 / Phase3(Day36-49)=2.5
    local phaseMult = NE.GetPhaseMult()

    -- 5. FogMult: 天候霧の影響 (屋外のみ, 最大 3.0x)
    local fogMult = 1.0
    if player:isOutside() then
        local fogIntensity = getClimateManager():getFogIntensity()
        fogMult = math.min(1.0 + fogIntensity, 3.0)
    end

    -- 6. DeltaMutation の算出 (設計書 4.11)
    local delta
    if zoneMult > 0 then
        -- 汚染圏内: 変異進行
        delta = NE.Config.BaseRate * locMult * maskMult * phaseMult * fogMult * zoneMult
    else
        -- 安全圏内: 自然回復 (設計書 4.3 / 12.2 NaturalRecovery=false がデフォルト)
        delta = NE.Config.RecoveryRate
        if player:isAsleep() then
            delta = delta * NE.Config.SleepMult
        end
    end

    -- 7. NE_MutationLevel への適用 (設計書 4.13)
    local newLevel = (modData.NE_MutationLevel or 0) + delta
    modData.NE_MutationLevel = math.max(0, math.min(newLevel, NE.Config.MaxMutation))

    -- 8. デバッグトレース (DEBUG)
    if NE.Switches.DebugLog and Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace(
            "NE_MUTATION", "Update",
            string.format(
                "Value:%.4f|Delta:%.4f|Zone:%.2f|Loc:%.2f|Mask:%.1f|Phase:%.1f|Fog:%.2f",
                modData.NE_MutationLevel, delta, zoneMult, locMult, maskMult, phaseMult, fogMult
            )
        )
    end
end
