-- --------------------------------------------------------------------------
-- NE_StartScene.lua
-- Role: 初期スポーン演出・初期アイテム配布・Dr.Hiro 遺体生成
-- 設計書 §3
--
-- ■ B42 API 裏取り済み (バニラコードで確認):
--   teleportTo          : DebugContextMenu.lua:1175  → player:teleportTo(x, y, z)
--   GasMask ID          : scripts/generated/items/clothing.txt → Base.Hat_GasMask
--   HazmatSuit ID       : 同上 → Base.HazmatSuit
--   HospitalGown        : 同上 → Base.HospitalGown
--   instanceof          : DebugContextMenu.lua:349  → instanceof(obj, "ClassName")
--   ISModalDialog       : ISUI/ISModalDialog.lua:187 → ISModalDialog:new(x,y,w,h,text,yesno,target,onclick,player,p1,p2)
--                         onClick が destroy() を先行呼び出しするため、コールバック内の destroy() は不要
--   getText 翻訳         : Translate/JP/UI.json (既存)
--   createZombie        : Umbrella-main __global.lua:621 / Tutorial/Steps.lua:1088
--   IsoDeadBody.new     : Javadoc IsoDeadBody(IsoGameCharacter,boolean) / Tutorial/Steps.lua:1096
--   zombie:getInventory : Umbrella-main IsoGameCharacter.lua:1442
--
-- ■ トリガー設計:
--   通常プレイ    → Events.OnCreatePlayer (NE_StartSceneFinished フラグでガード)
--   デバッグワープ → NE.StartScene.ForceRun(player)
-- --------------------------------------------------------------------------

NE            = NE            or {}
NE.StartScene = NE.StartScene or {}
NE.InitialEvent = NE.InitialEvent or {}

-- 初期スポーン座標 (設計書 3.1)
local START_X = 15640
local START_Y = 3909
local START_Z = 0

-- Dr.Hiro の生成起点 (設計書 3.3) — 壁めり込み回避のため 15641,3909
local HIRO_X = 15641
local HIRO_Y = 3909
local HIRO_Z = 0

-- 病院着・ガスマスク・ハザマットの初期耐久（設計書 3.3: 5% / ぼろぼろ）
local INITIAL_GEAR_CONDITION_RATIO = 0.05

---@param item InventoryItem|nil
local function applyRaggedCondition(item)
    if not item or not item.getConditionMax or not item.setCondition then return end
    local maxC = item:getConditionMax()
    if not maxC or maxC <= 0 then return end
    item:setCondition(math.max(1, math.ceil(maxC * INITIAL_GEAR_CONDITION_RATIO)))
end

-- --------------------------------------------------------------------------
-- 装着の完全解除 (設計書 3.3 / SS 対策: インベントリ空でも装備だけ残るケース)
-- B42: getWornItems():clear() を優先、不可なら各スロットを setWornItem(loc, nil)
-- --------------------------------------------------------------------------

---@param player IsoPlayer
local function stripAllWornItems(player)
    if not player then return end
    local worn = player.getWornItems and player:getWornItems() or nil
    if not worn then return end

    if worn.clear then
        pcall(function() worn:clear() end)
    end

    -- clear 後も残る環境向け: 列挙して nil で外す（複数パスで取りこぼし防止）
    if not (worn.size and worn.get) then return end
    local safety = 0
    while worn:size() > 0 and safety < 24 do
        safety = safety + 1
        local locs = {}
        for i = 0, worn:size() - 1 do
            local wi = worn:get(i)
            if wi and wi.getItem then
                local item = wi:getItem()
                if item and item.getBodyLocation then
                    local loc = item:getBodyLocation()
                    if loc then locs[#locs + 1] = loc end
                end
            end
        end
        if #locs == 0 then break end
        for _, loc in ipairs(locs) do
            pcall(function() player:setWornItem(loc, nil) end)
        end
    end
end

-- --------------------------------------------------------------------------
-- 初期装備セットアップ (設計書 3.3)
-- B42 確認済み API: getInventory / AddItem / setWornItem / getBodyLocation /
--                   setCondition / getConditionMax
-- --------------------------------------------------------------------------

---@param player IsoPlayer
local function setupInitialEquipment(player)
    local inventory = player:getInventory()
    if not inventory then return end

    stripAllWornItems(player)

    -- 既存アイテムを全削除 (ItemContainer:clear は B41/B42 共通)
    inventory:clear()

    -- 病院着を着用状態で追加（耐久はぼろぼろ＝設計書どおり 5%）
    local ok, err = pcall(function()
        local gown = inventory:AddItem("Base.HospitalGown")
        if gown then
            applyRaggedCondition(gown)
            player:setWornItem(gown:getBodyLocation(), gown)
        end
    end)
    if not ok and Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_SCENE", "Equipment", "Gown:ERR:" .. tostring(err), "WARN")
    end

    -- ガスマスク（ぼろぼろ）
    -- B42: Base.GasMask は存在しない。正しくは Base.Hat_GasMask (with filter drainable)
    local mask = inventory:AddItem("Base.Hat_GasMask")
    if mask then applyRaggedCondition(mask) end

    -- ハザマットスーツ（ぼろぼろ）
    local hazmat = inventory:AddItem("Base.HazmatSuit")
    if hazmat then applyRaggedCondition(hazmat) end

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_SCENE", "Equipment", "Setup:OK", "INFO")
    end
end

-- --------------------------------------------------------------------------
-- §3.2 喉の負傷（開始時に一度適用）
-- MDD: 即死回避のため DeepWound は使わない。Throat があれば優先、なければ Neck。
-- 「点滴破片」は存在する API のみ pcall で付与（無ければ痛み・擦り傷・出血のみ）
-- --------------------------------------------------------------------------

---@param player IsoPlayer
local function applyPrologueThroatInjury(player)
    if not player then return end
    local bd = player.getBodyDamage and player:getBodyDamage() or nil
    if not bd or not bd.getBodyPart then return end

    local part = nil
    if BodyPartType and BodyPartType.Throat then
        part = bd:getBodyPart(BodyPartType.Throat)
    end
    if not part and BodyPartType and BodyPartType.Neck then
        part = bd:getBodyPart(BodyPartType.Neck)
    end
    if not part then return end

    if part.setAdditionalPain then part:setAdditionalPain(60.0) end
    if part.AddDamage then part:AddDamage(1.5) end
    if part.setScratched then part:setScratched(true, false) end
    if part.setBleedingTime then part:setBleedingTime(5.0) end

    pcall(function()
        if part.setHaveGlass then
            part:setHaveGlass(true)
        elseif part.setSplinter then
            part:setSplinter(true)
        elseif part.setEmbeddedGlass then
            part:setEmbeddedGlass(true)
        end
    end)

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_SCENE", "Throat", "PrologueInjury:APPLIED", "INFO")
    end
end

-- --------------------------------------------------------------------------
-- Dr.Hiro 遺体生成 (設計書 3.3)
-- チャンクロード確認後に spawn するため OnTick ループで待機
--
-- ■ B42 バニラ確認済み API:
--   createZombie(x,y,z,desc,palette,dir) ← Umbrella-main __global.lua:621
--                                           Tutorial/Steps.lua:1088
--   zombie:dressInRandomOutfit()          ← Umbrella-main IsoZombie.lua:124
--                                           Tutorial/Steps.lua:1094
--   zombie:DoZombieInventory()            ← Umbrella-main IsoZombie.lua:14
--                                           Tutorial/Steps.lua:1095
--   zombie:getInventory()                 ← Umbrella-main IsoGameCharacter.lua:1442
--   IsoDeadBody.new(zombie, false)        ← Javadoc IsoDeadBody(IsoGameCharacter,boolean)
--                                           Tutorial/Steps.lua:1096
--
-- ■ 廃止した誤り:
--   IsoDeadBody.new(cell)   → 座標なし遺体を生成 → FBORenderCell クラッシュの原因
--   targetSquare:addCorpse  → Umbrella-main IsoGridSquare.lua に存在しない (Lua 非露出)
--   body:getInventory()     → IsoDeadBody は IsoGameCharacter 非継承 → Lua 非露出
-- --------------------------------------------------------------------------

---@param player IsoPlayer
local function spawnDrHiroWithRetry(player)
    local retries    = 0
    local maxRetries = 30  -- 最大 30 ティック待機 (~0.5秒)

    local function onTick()
        retries = retries + 1

        -- タイムアウト
        if retries >= maxRetries then
            Events.OnTick.Remove(onTick)
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Spawn:TIMEOUT", "WARN")
            return
        end

        -- チャンクロード確認
        local cell = getCell()
        if not cell then return end
        local targetSquare = cell:getGridSquare(HIRO_X, HIRO_Y, HIRO_Z)
        if not (targetSquare and instanceof(targetSquare, "IsoGridSquare")) then
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Spawn:WAIT:ChunkNotLoaded", "DEBUG")
            return  -- 次ティックで再試行
        end

        -- チャンクがロード済み → 即座にリスナーを除去してからスポーン実行
        -- これにより、スポーン中にエラーが起きても OnTick は二度と呼ばれない
        Events.OnTick.Remove(onTick)
        Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Spawn:START", "DEBUG")

        -- ゾンビ生成 → アイテム追加 → 遺体変換
        -- Tutorial/Steps.lua:1088-1096 のパターン確認済み
        -- fail-fast: pcall なし。Java 例外はスタックトレースごと surface させる

        -- [1] createZombie
        --     第 6 引数: IsoDirections.S を必ず渡す (nil → NPE in ordinal())
        local zombie = createZombie(HIRO_X, HIRO_Y, HIRO_Z, nil, 0, IsoDirections.S)
        if not zombie then
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Spawn:FAILED|zombie=nil", "ERROR")
            return
        end

        -- [2] インベントリ完全消去 (バニラ自動生成アイテムを除去)
        --     ItemContainer.clear() ← Javadoc zombie/inventory/ItemContainer.html line 353 (小文字)
        --     worn items は ItemContainer とは別管理なので clear() の影響を受けない
        local inv = zombie:getInventory()
        if not inv then
            player:Say("ヒロ博士の遺体生成に失敗しました。(inv=nil)")
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Spawn:ERR|inv=nil", "ERROR")
            return
        end
        inv:clear()

        -- [3] 白衣 (JacketLong_Doctor) を手動装着
        --     ItemContainer.AddItem(String) ← Javadoc line 125 (大文字 A)
        --     InventoryItem.getBodyLocation() ← Javadoc zombie/inventory/InventoryItem.html line 516
        --     IsoGameCharacter.setWornItem(ItemBodyLocation, InventoryItem) ← Javadoc line 385
        --     Base.JacketLong_Doctor ← generated/items/clothing.txt 確認済み
        local jacket = inv:AddItem("Base.JacketLong_Doctor")
        if jacket then
            zombie:setWornItem(jacket:getBodyLocation(), jacket)
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Dress:JacketLong_Doctor:OK", "DEBUG")
        else
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Dress:JacketLong_Doctor:nil", "WARN")
        end

        -- [4] スリッパ (Shoes_Slippers) を手動装着
        --     Base.Shoes_Slippers ← generated/items/clothing.txt 確認済み
        local slippers = inv:AddItem("Base.Shoes_Slippers")
        if slippers then
            zombie:setWornItem(slippers:getBodyLocation(), slippers)
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Dress:Shoes_Slippers:OK", "DEBUG")
        else
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Dress:Shoes_Slippers:nil", "WARN")
        end

        -- [5] インベントリ所持品: FirstAidKit + B17_AccessKey
        --     FirstAidKit は CanBeEquipped なし → worn 不可。インベントリに格納して遺体漁り時に発見させる
        --     Base.FirstAidKit ← generated/items/container.txt 確認済み (Medical=true, Capacity=4)
        --     他の候補: Base.FirstAidKit_Military (軍用), Base.FirstAidKit_Camping (キャンプ用)
        inv:AddItem("Base.FirstAidKit")
        Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Item:FirstAidKit:Added", "DEBUG")
        inv:AddItem("NOX_EVO_B42.B17_AccessKey")
        Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Item:B17_AccessKey:Added", "DEBUG")

        -- [6] 名前を "Dr. Hiro" に固定
        --     SurvivorDesc.setForename/setSurname ← Javadoc zombie/characters/SurvivorDesc.html line 111, 117
        --     IsoGameCharacter.getDescriptor() ← Javadoc IsoGameCharacter.html line 349
        local desc = zombie:getDescriptor()
        if desc then
            desc:setForename("Dr.")
            desc:setSurname("Hiro")
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Name:Set:DrHiro", "DEBUG")
        else
            Z_TRACER.EmitTrace("NE_SCENE", "DrHiro", "Name:desc=nil:SKIP", "WARN")
        end

        -- [7] IsoDeadBody.new(IsoGameCharacter, boolean) でゾンビを遺体に変換
        --     Javadoc IsoDeadBody(IsoGameCharacter,boolean) / Tutorial/Steps.lua:1096 確認済
        local body = IsoDeadBody.new(zombie, false)

        Z_TRACER.EmitTrace("NE_SCENE", "DrHiro",
            string.format("Spawn:OK|body=%s|(%d,%d,%d)",
                tostring(body ~= nil), HIRO_X, HIRO_Y, HIRO_Z), "INFO")
    end

    Events.OnTick.Add(onTick)
end

---@param player IsoPlayer
function NE.InitialEvent.setupInitialState(player)
    if not player then return end

    -- TechDebt-01: OnCreatePlayer はロード時も発火するため二重実行を防ぐ
    local modData = player:getModData()
    if modData.NE_SetupFinished then
        Z_TRACER.EmitTrace("NE_SCENE", "Setup", "Skip:AlreadyFinished", "DEBUG")
        return
    end

    modData.NE_SetupFinished = true

    setupInitialEquipment(player)
    spawnDrHiroWithRetry(player)
    NE.InitPlayerData(player)
end

-- --------------------------------------------------------------------------
-- シネマティック演出 (設計書 3.2)
-- 暗転系 API は使わず、ページダイアログを表示。
-- ページ終了時またはエラー時はそのままインゲームを開始。
-- --------------------------------------------------------------------------

---@param player IsoPlayer
local function showIntroDialogue(player)
    -- 翻訳キーは Translate/JP/UI.json に定義済み
    local pageKeys = {
        "UI_NE_Start_1",
        "UI_NE_Start_2",
        "UI_NE_Start_3",
        "UI_NE_Start_4",
        "UI_NE_Start_5",
    }
    local pageIndex = 1
    local currentDlg = nil  -- 重複防止用: 表示中ダイアログの参照

    local function showPage()
        if pageIndex > #pageKeys then return end
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_SCENE", "Intro",
                "showPage|pageIndex=" .. tostring(pageIndex) .. "|key=" .. tostring(pageKeys[pageIndex]), "DEBUG")
        end
        local text = getText(pageKeys[pageIndex])

        -- 既存ダイアログを除去 (重複防止)
        -- removeFromUIManager は ISCharacterInfo.lua:70 等で確認済み
        if currentDlg then
            pcall(function() currentDlg:removeFromUIManager() end)
            currentDlg = nil
        end

        -- ページ 3: 地面の血・嘔吐音・首の擦り傷相当（DeepWound / Fluid 系は不使用）
        local isNeckWoundPage = (pageIndex == 3) and (pageKeys[pageIndex] == "UI_NE_Start_3")
        if isNeckWoundPage then
            if Z_TRACER and Z_TRACER.EmitTrace then
                Z_TRACER.EmitTrace("NE_SCENE", "Intro", "NeckWoundPage:TRIGGER|pageIndex=3|UI_NE_Start_3", "INFO")
            end
            local sq = player and player:getCurrentSquare() or nil
            if Z_TRACER and Z_TRACER.EmitTrace then
                local px = player and player:getX()
                local py = player and player:getY()
                Z_TRACER.EmitTrace("NE_SCENE", "Intro",
                    "NeckWoundPage:sqPresent=" .. tostring(sq ~= nil) .. "|player=" .. tostring(player ~= nil)
                        .. "|xy=" .. tostring(px) .. "," .. tostring(py), "DEBUG")
            end
            if sq then
                sq:splatBlood(5, 5)
                player:playSound("Vomit")
                -- 身体症状は開始時 applyPrologueThroatInjury で適用済み（二重デバフ回避）
                player:Say(getText("UI_NE_Start_3_ThroatPain"))
            elseif Z_TRACER and Z_TRACER.EmitTrace then
                Z_TRACER.EmitTrace("NE_SCENE", "Intro", "NeckWoundPage:sq=nil|SKIP", "WARN")
            end
        end

        -- 画面中央座標を計算
        -- LuaLS / バインディング上は Core のインスタンスメソッドとして getCore():getScreenWidth() 形式
        -- ISModalDialog:new に x=0,y=0 を渡すとマウス位置起点になるため明示指定が必要
        -- (ISModalDialog.lua:192-207 参照)
        local DLG_W, DLG_H = 380, 180
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        -- CalcSize でテキスト量に応じた最終サイズを取得してから中央計算
        local finalW, finalH = ISModalDialog.CalcSize(DLG_W, DLG_H, text)
        local dlgX = math.floor((sw - finalW) / 2)
        local dlgY = math.floor((sh - finalH) / 2)

        local ok, err = pcall(function()
            local dlg = ISModalDialog:new(dlgX, dlgY, DLG_W, DLG_H, text, false, nil,
                function(target, button)
                    -- destroy() は ISModalDialog:onClick が先に呼ぶため不要
                    -- (ISModalDialog.lua:59 参照)
                    currentDlg = nil
                    pageIndex = pageIndex + 1
                    if pageIndex <= #pageKeys then
                        showPage()
                    else
                        if Z_TRACER and Z_TRACER.EmitTrace then
                            Z_TRACER.EmitTrace("NE_SCENE", "Intro", "Cinematic:DONE", "INFO")
                        end
                    end
                end
            )
            dlg:initialise()
            local dlgBtn = dlg.yes or dlg.ok
            if dlgBtn then
                dlgBtn:setTitle(getText("UI_Next"))
            end
            local isFinalPage = (pageIndex == 5) and (pageKeys[pageIndex] == "UI_NE_Start_5")
            if isFinalPage and dlgBtn then
                dlgBtn:setTitle(getText("UI_Finish"))
            end
            dlg:addToUIManager()
            currentDlg = dlg
        end)

        if not ok then
            currentDlg = nil
            if Z_TRACER and Z_TRACER.EmitTrace then
                Z_TRACER.EmitTrace("NE_SCENE", "Intro",
                    "Dialog:FALLBACK|page=" .. pageIndex .. "|text=" .. tostring(text) .. "|err=" .. tostring(err), "WARN")
            end
        end
    end

    showPage()
end

-- --------------------------------------------------------------------------
-- メインエントリーポイント
-- --------------------------------------------------------------------------

---@param player IsoPlayer
---@param skipCinematic boolean
local function runStartScene(player, skipCinematic)
    local modData = player:getModData()
    -- 非同期ダイアログ中の OnCreatePlayer 再発火による二重生成（Dr.Hiro 等）を防ぐ
    modData.NE_StartSceneFinished = true

    -- テレポート: B42 バニラ確認済み (DebugContextMenu.lua:1175)
    player:teleportTo(START_X, START_Y, START_Z)

    -- 初期状態のセットアップ（装着全解除 → 病院着のみ再装着、設計書 3.3）
    NE.InitialEvent.setupInitialState(player)
    applyPrologueThroatInjury(player)

    -- 演出の実行
    if skipCinematic then
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_SCENE", "Intro", "Cinematic:SKIPPED(debug)", "INFO")
        end
    else
        showIntroDialogue(player)
    end

    if Z_TRACER and Z_TRACER.EmitTrace then
        Z_TRACER.EmitTrace("NE_SCENE", "StartScene",
            "Run:OK|Debug:" .. tostring(skipCinematic), "INFO")
    end
end

-- --------------------------------------------------------------------------
-- イベントハンドラ
-- --------------------------------------------------------------------------

local function OnCreatePlayer(playerIndex, player)
    if not player then return end
    local modData = player:getModData()

    if modData.NE_StartSceneFinished then
        if Z_TRACER and Z_TRACER.EmitTrace then
            Z_TRACER.EmitTrace("NE_SCENE", "StartScene", "Guard:AlreadyFinished", "DEBUG")
        end
        return
    end

    local function runOnNextTick()
        Events.OnTick.Remove(runOnNextTick)
        runStartScene(player, false)
    end
    Events.OnTick.Add(runOnNextTick)
end

--- デバッグ強制実行 (NE_DebugMenu 経由)
---@param player IsoPlayer
function NE.StartScene.ForceRun(player)
    if not player then return end
    runStartScene(player, true)
end

-- --------------------------------------------------------------------------
-- イベント登録
-- --------------------------------------------------------------------------
Events.OnCreatePlayer.Remove(OnCreatePlayer)
Events.OnCreatePlayer.Add(OnCreatePlayer)

if Z_TRACER and Z_TRACER.EmitTrace then
    Z_TRACER.EmitTrace("NE_INIT", "StartScene", "Load:OK", "INFO")
end
