-- Challenge_NOX_EVOLVED.lua
-- LastStandData はメインメニューの Lua ロード時のみ存在する。
-- ゲームセッション開始時の ResetLua では require が失敗し nil になるため、
-- 登録処理は nil ガードで保護する。
require "LastStand/LastStandData"

local challenge = {}
challenge.id = "NOX_EVOLVED"
challenge.name = "NOX: EVOLVED"
challenge.description = "Challenge_NOX_EVOLVED_Desc"
challenge.image = "media/textures/NE_Challenge_Poster.png"
challenge.gameMode = "Sandbox"
challenge.worldMap = "Muldraugh, KY"
challenge.x = 15640
challenge.y = 3909
challenge.z = 0

-- サンドボックス変数の強制上書き (設計書 13.2)
challenge.AddSandboxOptions = function()
    SandboxVars.ErosionDays = 1825
    SandboxVars.StartMonth  = 7

    local noxVars = SandboxVars.NOX_EVO_B42
    if type(noxVars) == "table" then
        noxVars.MutationBaseRate  = 0.3
        noxVars.ExpansionRate     = 80.0
        noxVars.DaysToAirstrike   = 50
    end

    SandboxVars.Zombies      = 3
    SandboxVars.LootRareness = 1
end

-- 初期状態のセットアップ (設計書 13.3)
challenge.OnInitPlayer = function(player)
    if NE and NE.InitialEvent and NE.InitialEvent.setupInitialState then
        NE.InitialEvent.setupInitialState(player)
    end
    -- 変異度 20% から開始 (設計書 13.3)
    if player then
        player:getModData().NE_MutationLevel = 20.0
    end
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "Challenge", "OnInitPlayer:MutationLevel=20.0", "INFO")
    end
end

-- LastStandData が存在する場合のみ登録（ゲームセッション中の ResetLua では nil）
if LastStandData then
    table.insert(LastStandData, challenge)
    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_INIT", "Challenge", "Registered:NOX_EVOLVED", "INFO")
    end
end