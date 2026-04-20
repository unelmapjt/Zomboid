-- --------------------------------------------------------------------------
-- NE_IntroText.lua
-- Role: 起動時のブラックスクリーン・イントロテキストを NOX: EVOLVED 専用に上書きする
-- --------------------------------------------------------------------------

require "OptionScreens/ISSceneIntro"

local original_ISSceneIntro_createChildren = ISSceneIntro.createChildren

function ISSceneIntro:createChildren()
    -- オリジナルの処理を先に走らせる（UI要素の生成など）
    original_ISSceneIntro_createChildren(self)

    -- 現在のゲームモードまたはチャレンジ名を確認
    -- Core.getGameMode() が "Challenge" かどうかで判定
    local isNoxEvolved = false
    
    -- チャレンジ名を特定（MainScreen.instance.desc.name 等で判定可能）
    -- B42 では Challenge 選択時に MainScreen.instance.desc がセットされる
    if MainScreen.instance and MainScreen.instance.desc and MainScreen.instance.desc.name == "NOX: EVOLVED" then
        isNoxEvolved = true
    end

    -- デバッグ時や強制適用フラグがある場合はここで判定可能
    if isNoxEvolved then
        -- テキスト行を NOX: EVOLVED 専用の 5 行に差し替える
        -- バニラは通常 3 行だが、ISSceneIntro は self.lines の要素数分フェードを繰り返す
        self.lines = {
            getText("UI_NE_Intro_1"),
            getText("UI_NE_Intro_2"),
            getText("UI_NE_Intro_3"),
            getText("UI_NE_Intro_4"),
            getText("UI_NE_Intro_5")
        }
        
        -- フェード速度や待機時間を調整したい場合は以下のプロパティを操作可能
        -- self.displayTime = 200 -- 1行の表示時間
    end
end
