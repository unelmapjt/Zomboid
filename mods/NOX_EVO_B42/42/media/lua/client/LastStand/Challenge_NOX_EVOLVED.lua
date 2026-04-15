-- Challenge_NOX_EVOLVED.lua
require "LastStand/LastStandData"

local challenge = {}
challenge.id = "NOX_EVOLVED"
challenge.name = "NOX: EVOLVED"
challenge.description = "Challenge_NOX_EVOLVED_Desc" -- 翻訳キーを参照
challenge.image = "media/textures/NE_Challenge_Poster.png"
challenge.gameMode = "Sandbox"
challenge.worldMap = "Muldraugh, KY"
challenge.x = 15640 -- ルイビル救護所初期座標
challenge.y = 3909 
challenge.z = 0    

-- サンドボックス変数の強制上書き (黙示録とCDDAの中間)
challenge.AddSandboxOptions = function()
    -- 環境：超加速侵食 (5年相当の劣化)
    SandboxVars.ErosionDays = 1825 
    SandboxVars.StartMonth = 7 -- 7月開始
    
    -- 難易度：中間の絶望
    SandboxVars.NOX_EVO_B42.MutationBaseRate = 0.3 -- 基礎変異上昇率
    SandboxVars.NOX_EVO_B42.ExpansionRate = 80.0   -- 侵食拡大速度
    SandboxVars.NOX_EVO_B42.DaysToAirstrike = 50   -- 空爆までの日数
    
    -- バニラ変数
    SandboxVars.Zombies = 3 -- ゾンビの多さ (High)
    SandboxVars.LootRareness = 1 -- 物資の希少度 (Extremely Rare)
end

-- 初期状態のセットアップ
challenge.OnInitPlayer = function(player)
    -- 第3.3節のセットアップを実行
    NE.InitialEvent.setupInitialState(player)
    
    -- 変異度 20% から開始 (「何か嫌な味がする」状態)
    player:getModData().NE_MutationLevel = 20.0
end

table.insert(LastStandData, challenge)