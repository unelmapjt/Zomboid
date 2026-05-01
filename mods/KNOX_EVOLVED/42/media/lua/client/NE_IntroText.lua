-- --------------------------------------------------------------------------
-- NE_IntroText.lua (Build 42)
-- Role: タイトル画面（MainScreen）の背景差し替え
-- MDD §13.x (Title Screen Override)
-- --------------------------------------------------------------------------

require "OptionScreens/MainScreen"

-- 背景テクスチャと状態管理
local NEMainScreen = {}

local function initTextures(self)
    if not self.noxTitleTextureBG then
        self.noxTitleTextureBG = getTexture("media/ui/pztitle_colour.png")
        self.noxAlphaBG = 0
    end
end

-- MainScreen:initialise を拡張してテクスチャをロード
local original_MainScreen_initialise = MainScreen.initialise
function MainScreen:initialise()
    original_MainScreen_initialise(self)
    initTextures(self)
end

-- MainScreen.prerender をフックして背景を描画
local original_MainScreen_prerender = MainScreen.prerender
function MainScreen:prerender()
    -- 必ず先にバニラ prerender を実行する（先に return するとメニューがクリック不能になる）
    original_MainScreen_prerender(self)

    -- NOX 差し替え背景のみスキップ（プレイ中／ゲーム由来のメニュー）。getWorld はメニュー中も真になり得るため使わない
    if getPlayer() ~= nil or self.inGame == true then
        self.noxAlphaBG = 0
        return
    end

    -- 初期化の二重保証
    initTextures(self)

    if self.noxTitleTextureBG then
        -- alphaの更新
        if not self.noxAlphaBG then self.noxAlphaBG = 0 end
        
        -- ローテーションなどの演出中（Indie Stoneロゴなど）は 0 に固定される可能性があるため、
        -- 常に僅かずつ加算する
        self.noxAlphaBG = math.min(1.0, self.noxAlphaBG + 0.005)
        
        -- ロゴの背後に隠れないよう、バニラの描画の後に上書き
        UIManager.DrawTexture(self.noxTitleTextureBG, 0, 0, self.width, self.height, self.noxAlphaBG)
    end
end

-- メインメニューに入った際（戻った際）のフェードリセット用
Events.OnMainMenuEnter.Add(function()
    if MainScreen.instance then
        MainScreen.instance.noxAlphaBG = 0
    end
end)
