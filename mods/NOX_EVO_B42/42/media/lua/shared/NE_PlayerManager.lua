-- --------------------------------------------------------------------------
-- Path: media/lua/shared/NE_PlayerManager.lua
-- Role: プレイヤー単位の生存ロジックの管理（定期更新・初期化）
-- --------------------------------------------------------------------------

NE = NE or {}

--- プレイヤー作成・読み込み時の初期化処理
---@param playerIndex number
---@param player IsoPlayer
local function OnCreatePlayer(playerIndex, player)
    -- NE_Core.lua で定義した初期化を実行
    NE.InitPlayerData(player)
end

--- 定期的な生存判定（1分ごと）
local function OnEveryOneMinute()
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
            local currentDay = NE.GetCurrentDay()
            local lastDay = modData.NE_LastUpdateDay or -1

            -- 10タイル以上の移動があったか、または日付が変わった場合のみ再計算する
            local forceRecalc = (distSq >= 100) or (currentDay ~= lastDay)
            
            if forceRecalc then
                modData.NE_LastUpdateX = x
                modData.NE_LastUpdateY = y
                modData.NE_LastUpdateDay = currentDay
            end

            -- NE_Pollution.lua で定義した汚染更新処理を実行
            if NE.UpdatePollution then
                NE.UpdatePollution(player, forceRecalc)
            end
        end
    end
end

-- イベント登録
-- 初期化
Events.OnCreatePlayer.Add(OnCreatePlayer)
-- 汚染更新 (1分ごと)
Events.EveryOneMinute.Add(OnEveryOneMinute)

print("NOX: EVOLVED - Shared: NE_PlayerManager ロード完了。")
