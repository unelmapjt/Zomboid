-- --------------------------------------------------------------------------
-- NE_Mutation.lua
-- Role: プレイヤーの変異度 (NE_MutationLevel) 更新ロジック
-- 設計書 4.11: DeltaMutation = BaseRate × LocMult × MaskMult × PhaseMult × FogMult × ZoneMultiplier
--
-- 室内: LocMult は TargetLocMult に向けた NE_CurrentInternalLocMult（modData）を使用。
-- 屋外: LocMult = Open（即時）。
--
-- ZoneMultiplier: 設計書 §4.10 非対称遷移（§4.9 は視覚同期。倍率の粘り気は §4.10）。
--   悪化（Safe→Danger / 低倍率→高倍率）: 即時反映。NE_LastZoneDangerTime を更新。
--   改善（Danger→Safe）: NE_LastZoneDangerTime から ZoneHysteresisMinutes 分経過まで高倍率を維持。
--
-- ■ Delta=1.5 検証 (Zone3 / 屋外 / マスクなし / Phase1 / 霧なし):
--   0.5(Base) × 1.0(Open) × 3.0(NoMask) × 1.0(Phase1) × 1.0(NoFog) × 1.0(Zone3) = 1.5 ✓
-- --------------------------------------------------------------------------

NE = NE or {}

local NE_ZONE_EPS = 1e-5

--- 静的目標 LocMult（屋外=Open / 車両・研究系=Sealed / 一般室内=Partial）
---@param player IsoPlayer
---@param square IsoGridSquare|nil
---@return number targetLocMult
function NE.GetTargetLocMult(player, square)
    if not player or not square then
        return NE.Config.LocMult.Partial
    end
    if player:isOutside() then
        return NE.Config.LocMult.Open
    end
    local vehicle = player:getVehicle()
    if vehicle then
        return NE.Config.LocMult.Sealed
    end
    local room = square:getRoom()
    if room then
        local roomDef = room:getRoomDef()
        if roomDef then
            local roomName = string.lower(roomDef:getName() or "")
            if string.find(roomName, "research")
                or string.find(roomName, "military")
                or string.find(roomName, "laboratory")
                or string.find(roomName, "prison") then
                return NE.Config.LocMult.Sealed
            end
        end
    end
    return NE.Config.LocMult.Partial
end

---@param target number
---@return number M 収束に用いる分母（分）
local function NE_GetConvergenceMinutesForTarget(target)
    local cfg = NE.Config.LocMultConvergenceMinutes
    if not cfg then
        return 30
    end
    if target == NE.Config.LocMult.Open then
        return cfg.Open or 5
    end
    if target == NE.Config.LocMult.Partial then
        return cfg.Partial or 30
    end
    if target == NE.Config.LocMult.Sealed then
        return cfg.Sealed or 30
    end
    return cfg.Partial or 30
end

--- current を target に近づける。スキップ分は elapsed に比例（最大 M 分で残差ゼロ）
--- 毎分 1 分のとき factor=1/M → 目安どおり Open は約 5 分、Partial/Sealed は約 30 分で到達
---@param current number
---@param target number
---@param elapsedMinutes number
---@param M number
---@return number
local function NE_ConvergeInternalLocMult(current, target, elapsedMinutes, M)
    if elapsedMinutes <= 0 or M <= 0 then
        return current
    end
    local f = math.min(1, elapsedMinutes / M)
    return current + (target - current) * f
end

---@return number worldMinutes getGameTime():getWorldAgeHours() * 60
local function NE_GetWorldMinutes()
    local gt = getGameTime()
    if not gt then
        return 0
    end
    return gt:getWorldAgeHours() * 60
end

--- プレイヤーの変異度 (NE_MutationLevel) を 1分ごとに更新する
--- NE_PlayerManager.lua (client) の EveryOneMinute から呼ばれる
---@param player IsoPlayer
---@param forceRecalc boolean 10タイル以上の移動または日付変更があったとき true
function NE.UpdateMutation(player, forceRecalc)
    if not player or player:isDead() then return end
    if NE.Switches and NE.Switches.EnableMutation == false then return end

    local modData = player:getModData()
    if not modData then
        return
    end

    if modData.NE_MutationLevel == nil then
        modData.NE_MutationLevel = 20.0
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace(
                "NE_MUTATION",
                "Bootstrap",
                "Fired|context=UpdateMutation|level=20.0",
                "INFO"
            )
        end
    end

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace(
            "NE_MUTATION",
            "UpdateMutation",
            "Run|level=" .. tostring(modData.NE_MutationLevel),
            "INFO"
        )
    end

    local square = player:getCurrentSquare()
    if not square then return end

    -- 1. ZoneMultiplier: 毎分 raw を算出し、§4.10 ヒステリシスで適用倍率を決定
    local nowZone = NE_GetWorldMinutes()
    if modData.NE_LastZoneDangerTime == nil then
        modData.NE_LastZoneDangerTime = nowZone
    end
    local rawZoneMult = NE.GetZoneMultiplier(player:getX(), player:getY(), player:getZ())
    local lastZone = modData.NE_LastZoneMult
    local zoneMult
    local hysteresisActive = false
    local needHyst = (NE.Config and NE.Config.ZoneHysteresisMinutes) or 30

    if lastZone == nil then
        zoneMult = rawZoneMult
        modData.NE_LastZoneMult = rawZoneMult
        if rawZoneMult > NE_ZONE_EPS then
            modData.NE_LastZoneDangerTime = nowZone
        end
    elseif rawZoneMult > lastZone + NE_ZONE_EPS then
        -- 悪化: 即時反映（車で一瞬 Zone1 でも以後クールダウンまで高倍率が残る）
        zoneMult = rawZoneMult
        modData.NE_LastZoneMult = rawZoneMult
        modData.NE_LastZoneDangerTime = nowZone
    elseif rawZoneMult < lastZone - NE_ZONE_EPS then
        -- 改善: 最終危険検知から needHyst 分までは低い raw に落とさない
        local elapsedSinceDanger = nowZone - modData.NE_LastZoneDangerTime
        if elapsedSinceDanger < needHyst then
            zoneMult = lastZone
            modData.NE_LastZoneMult = lastZone
            hysteresisActive = true
            if Z_TRACER and Z_TRACER.EmitTrace then
                Z_TRACER.EmitTrace(
                    "NE_MUTATION",
                    "ZoneHysteresis",
                    string.format(
                        "Hold|raw:%.2f|cached:%.2f|elapsedMin:%.2f|needMin:%.0f|reason:ImproveCooldown",
                        rawZoneMult, lastZone, elapsedSinceDanger, needHyst
                    ),
                    "INFO"
                )
            end
        else
            zoneMult = rawZoneMult
            modData.NE_LastZoneMult = rawZoneMult
        end
    else
        zoneMult = lastZone
        modData.NE_LastZoneMult = lastZone
    end

    -- 2. LocMult: 屋外は即時 Open / 室内は Target に向けた動的 NE_CurrentInternalLocMult
    local targetLocMult = NE.GetTargetLocMult(player, square)
    local locMult
    local indoorTargetTrace = targetLocMult
    local currentInternalTrace = targetLocMult

    if player:isOutside() then
        locMult = NE.Config.LocMult.Open
        modData.NE_CurrentInternalLocMult = NE.Config.LocMult.Open
        currentInternalTrace = NE.Config.LocMult.Open
        indoorTargetTrace = NE.Config.LocMult.Open
        modData.NE_LastMutationUpdateTimestamp = NE_GetWorldMinutes()
    else
        local nowMin = NE_GetWorldMinutes()
        local lastTs = modData.NE_LastMutationUpdateTimestamp
        local elapsed
        if lastTs == nil then
            elapsed = 1
        else
            elapsed = math.max(0, nowMin - lastTs)
            if elapsed <= 0 then
                elapsed = 1
            end
        end
        modData.NE_LastMutationUpdateTimestamp = nowMin

        local cur = modData.NE_CurrentInternalLocMult
        if cur == nil then
            cur = NE.Config.LocMult.Open
        end
        local M = NE_GetConvergenceMinutesForTarget(targetLocMult)
        if elapsed > 0 then
            cur = NE_ConvergeInternalLocMult(cur, targetLocMult, elapsed, M)
        end
        local lo = math.min(NE.Config.LocMult.Sealed, NE.Config.LocMult.Partial, NE.Config.LocMult.Open)
        local hi = math.max(NE.Config.LocMult.Sealed, NE.Config.LocMult.Partial, NE.Config.LocMult.Open)
        if cur < lo then cur = lo end
        if cur > hi then cur = hi end
        modData.NE_CurrentInternalLocMult = cur
        locMult = cur
        currentInternalTrace = cur
        indoorTargetTrace = targetLocMult
    end

    -- 3. MaskMult: ガスマスク防護性能 (設計書 4.11)
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

    -- 4. PhaseMult: 世界の汚染段階 (設計書 11.1)
    --    Phase1(Day1-15)=1.0 / Phase2(Day16-35)=1.5 / Phase3(Day36-49)=2.5
    local phaseMult = NE.GetPhaseMult()

    -- 5. FogMult: 天候霧の影響 (屋外のみ, 最大 3.0x)
    local fogMult = 1.0
    if player:isOutside() then
        local fogIntensity = getClimateManager():getFogIntensity()
        fogMult = math.min(1.0 + fogIntensity, 3.0)
    end

    -- 6. DeltaMutation の算出 (設計書 4.11)
    -- zoneMult はヒステリシス適用後の値。<= 0 のときは汚染進行を行わず RecoveryRate のみ（通常は負値＝浄化）
    local delta
    if zoneMult > 0 then
        -- 汚染圏内: 変異進行（delta > 0 になり得る）
        delta = NE.Config.BaseRate * locMult * maskMult * phaseMult * fogMult * zoneMult
    else
        -- 安全圏内: 自然回復（RecoveryRate は NE_Config で負の浄化率）
        delta = NE.Config.RecoveryRate
        if player:isAsleep() then
            delta = delta * NE.Config.SleepMult
        end
    end

    -- 7. NE_MutationLevel への適用 (設計書 4.13)
    local newLevel = (modData.NE_MutationLevel or 20.0) + delta
    modData.NE_MutationLevel = math.max(0, math.min(newLevel, NE.Config.MaxMutation))

    -- 8. デバッグトレース (DEBUG)
    if NE.Switches.DebugLog and Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace(
            "NE_MUTATION", "Update",
            string.format(
                "Value:%.4f|Delta:%.4f|Zone:%.2f|Loc:%.2f|Mask:%.1f|Phase:%.1f|Fog:%.2f|IndoorTarget:%.2f|CurrentInternal:%.2f|Hysteresis:%s|RawZone:%.2f",
                modData.NE_MutationLevel, delta, zoneMult, locMult, maskMult, phaseMult, fogMult,
                indoorTargetTrace, currentInternalTrace,
                hysteresisActive and "true" or "false",
                rawZoneMult
            )
        )
    end
end
