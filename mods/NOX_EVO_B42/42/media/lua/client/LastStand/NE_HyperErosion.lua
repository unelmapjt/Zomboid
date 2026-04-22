-- --------------------------------------------------------------------------
-- media/lua/client/LastStand/NE_HyperErosion.lua
-- Role: チャレンジ「NOX: EVOLVED」（LastStand / CDDA 系と同一の登録パターン）
-- MDD §13.1: challenge.id は必ず NOX_EVOLVED
-- --------------------------------------------------------------------------
-- B42: Events.OnChallengeQuery → addChallenge が最優先。本ファイル末尾の1行のみ登録。
-- --------------------------------------------------------------------------

NE = NE or {}

local challenge = {}

challenge.id = "NOX_EVOLVED"
challenge.name = "Challenge_NOX_EVOLVED_name"
challenge.description = "Challenge_NOX_EVOLVED_desc"

local POSTER = "media/ui/nox_challenge_source.png"
challenge.image = POSTER
challenge.poster = POSTER
challenge.video = "NE_HyperErosion.bik"

challenge.gameMode = "Sandbox"
challenge.worldLength = 0
challenge.spawnRegion = "Muldraugh, KY"
challenge.worldMap = "Muldraugh, KY"
challenge.x = 15641
challenge.y = 3908
challenge.z = 0

local challengeAddDone = false

-- NOX 相当の世界か: gameMode ではなく侵食日数で判定（Sandbox チャレンジでも一致する）
local function isNoxErosionWorld()
    return SandboxVars and type(SandboxVars.ErosionDays) == "number" and SandboxVars.ErosionDays >= 1825
end

function challenge.Add()
    if challengeAddDone then return end
    challengeAddDone = true

    function challenge.Render()
    end

    -- MDD §2.4.1: LastStandSetup が無条件で呼ぶため、空でも定義必須
    function challenge.Init()
    end

    function challenge.AddPlayer(playerNum, playerObj)
    end

    function challenge.AddSandboxOptions()
        if not SandboxVars then return end
        SandboxVars.ErosionDays = 1825
        SandboxVars.StartMonth = 7
        pcall(function()
            SandboxVars.MonthsSinceApo = 60
        end)
        local noxVars = SandboxVars.NOX_EVOLVED or SandboxVars.NOX_EVO_B42 or SandboxVars.NOX_EVO
        if type(noxVars) == "table" then
            noxVars.MutationBaseRate = 0.3
            noxVars.DaysToAirstrike = 50
        end
        SandboxVars.Zombies = 3
        SandboxVars.LootRareness = 1
    end

    -- §13.2: ワールド初期化時点で開始月をサンドボックスに固定
    function challenge.OnInitWorld()
        if SandboxVars then
            SandboxVars.StartMonth = 7
        end
        local sandbox = getSandboxOptions()
        if not sandbox or not sandbox.setOptionByName then
            return
        end
        -- StartMonth 7（1-based の 7 月）が正。0–11 解釈の環境向けに 6 を先に試し、続けて 7 で上書き
        pcall(function()
            sandbox:setOptionByName("StartMonth", 6)
        end)
        pcall(function()
            sandbox:setOptionByName("ErosionDays", 1825)
            sandbox:setOptionByName("MonthsSinceApo", 60)
            sandbox:setOptionByName("StartMonth", 7)
            sandbox:setOptionByName("MutationBaseRate", 0.3)
            sandbox:setOptionByName("Zombies", 3)
            sandbox:setOptionByName("LootRareness", 1)
            sandbox:setOptionByName("DaysToAirstrike", 50)
        end)
    end

    function challenge.OnCreatePlayer(_, player)
        if not isNoxErosionWorld() then return end
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("CRITICAL", "Challenge", "FORCE_START_APPLIED", "INFO")
        end
        if player then
            player:getModData().NE_MutationLevel = 20.0
        end
    end

    function challenge.OnGameStartJulyOverride()
        if not isNoxErosionWorld() then return end
        local gt = getGameTime()
        if gt then
            gt:setMonth(6)
            gt:setDay(0)
        end
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("CRITICAL", "Challenge", "FORCE_INIT_DONE", "INFO")
        end
    end

    Events.OnInitWorld.Add(challenge.OnInitWorld)
    Events.OnCreatePlayer.Add(challenge.OnCreatePlayer)
    Events.OnGameStart.Add(challenge.OnGameStartJulyOverride)

    -- CDDA / 10YL 系: イベント登録のあとに addChallenge を最後に呼ぶ
    addChallenge(challenge)
end

Events.OnChallengeQuery.Add(challenge.Add)

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "Challenge",
        "Register:OnChallengeQuery|challenge.Add|OnInitWorld|OnCreatePlayer|OnGameStart|addChallenge", "INFO")
end
