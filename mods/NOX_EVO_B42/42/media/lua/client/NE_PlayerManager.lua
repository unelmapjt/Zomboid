-- --------------------------------------------------------------------------
-- Path: media/lua/client/NE_PlayerManager.lua
-- Role: プレイヤー単位の生存ロジックの管理 (クライアント側)
-- --------------------------------------------------------------------------

NE = NE or {}

-- 1. 初期化ログ (INFO)
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "Load:START", "INFO")
end

--- 定期的な生存判定（1分ごと）
local function OnEveryOneMinute()
    -- HEARTBEAT ログ (DEBUGレベル: 毎分のイベント発火を確認)
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_HEARTBEAT", "PlayerManager", "EveryOneMinute", "DEBUG")
    end

    -- 稼働している全プレイヤー（画面分割含む）に対してループ
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local modData = player:getModData()
            local x = player:getX()
            local y = player:getY()
            
            -- 前回の計算地点からの距離を確認 (10タイルの閾値)
            local lastX = modData.NE_LastUpdateX or -9999
            local lastY = modData.NE_LastUpdateY or -9999
            local dx = x - lastX
            local dy = y - lastY
            local distSq = (dx * dx) + (dy * dy)

            -- 日付が変わったかどうかもチェック
            local currentDay = NE.GetCurrentDay and NE.GetCurrentDay() or -1
            local lastDay = modData.NE_LastUpdateDay or -1

            -- 10タイル以上の移動があったか、または日付が変わった場合のみ再計算する
            local forceRecalc = (distSq >= 100) or (currentDay ~= lastDay)
            
            if forceRecalc then
                modData.NE_LastUpdateX = x
                modData.NE_LastUpdateY = y
                modData.NE_LastUpdateDay = currentDay
            end

            -- 変異度更新処理の実行 (ガード節とエラーログ)
            if NE.UpdateMutation then
                NE.UpdateMutation(player, forceRecalc)
            else
                if Z_TRACER and Z_TRACER.EmitTrace then
                    Z_TRACER.EmitTrace("NE_ERROR", "PlayerManager", "UpdateMutation:MISSING", "ERROR")
                end
            end
        end
    end
end

-- イベント登録
Events.EveryOneMinute.Add(OnEveryOneMinute)

-- 2. 完了ログ (INFO)
if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "PlayerManager", "Load:DONE", "INFO")
end
