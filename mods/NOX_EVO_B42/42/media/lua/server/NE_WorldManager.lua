-- --------------------------------------------------------------------------
-- Path: media/lua/server/NE_WorldManager.lua
-- Role: サーバー側での生存日数管理とワールドModDataの同期
-- --------------------------------------------------------------------------

NE = NE or {}

--- 生存日数の自動インクリメント処理
function NE.UpdateSurvivalDays()
    local modData = getGameTime():getModData()
    
    -- ゲーム開始からの累積経過時間を取得
    local hours = math.floor(getGameTime():getWorldAgeHours())
    -- 経過時間を日数に変換 (1日目からカウント)
    local currentDay = math.floor(hours / 24) + 1

    -- ModDataの値よりも日数が進んでいれば更新
    if not modData.NE_SurvivalDays or modData.NE_SurvivalDays < currentDay then
        modData.NE_SurvivalDays = currentDay
        print("NOX: EVOLVED - 生存日数が更新されました: " .. currentDay .. " 日目")
    end
end

-- 各種イベントへの登録
-- ワールド初期化時にModDataを準備
Events.OnInitWorld.Add(NE.InitWorldData)
-- ゲーム内10分ごとに日数の経過をチェック
Events.EveryTenMinutes.Add(NE.UpdateSurvivalDays)

print("NOX: EVOLVED - Server: NE_WorldManager ロード完了。")
