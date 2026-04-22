# NOX: EVOLVED - Granular Functionality Roadmap (B42)

> [!IMPORTANT]
> 本ロードマップは `Master Design Document.md` の現行仕様に完全同期する。
> 各フェーズの実装前に必ず対応章を精読し、`Z_Core.lua` / `Z_Tracer.lua` による
> 決定論的デバッグループを維持すること。

### 凡例
| 記号 | 意味 |
| :---: | :--- |
| `[x]` | 実装済み |
| `[-]` | 部分実装（残作業あり） |
| `[ ]` | 未実装 |
| `- [ ] 検証` | ゲーム内動作確認チェック（実装後に記入） |

---

## Phase 1: Foundation & Data Integrity (設計書 §4.1, §4.13, §16)

- [x] **1.1 Global Config Audit**
  `NE.Config` への全定数集約と重複排除。
  - `BaseRate=0.5`, `MaxMutation=100`, `RecoveryRate=-0.005`, `SleepMult=5.0` を単一テーブルで管理。
  - `LocMult` (Open/Partial/Sealed), `MaskMult` (Good/Broken/None), `ExpansionRate=80.0` を含む。
  - `SandboxVars.NOX_EVO_B42` との同期ロジック (`refreshSandboxSwitches`) を保証。
  - [ ] 検証: `NE_DIAG` トレースで全スイッチ値が正しく表示されること。

- [x] **1.2 ModData Serialization**
  `player:getModData()` を用いた変異度・進化ポイントの永続化基盤。
  - 保存フィールド: `NE_MutationLevel`, `NE_LastZoneMult`, `NE_LastUpdateX/Y/Day`。
  - ロード時の復元: `Events.OnCreatePlayer` で既存データがあれば初期化をスキップ。
  - ワールドデータ: `getGameTime():getModData()` に `NE_SurvivalDays`, `NE_Phase`。
  - [ ] 検証: セーブ→ロード後に `NE_MutationLevel` が正しく復元されること。

- [x] **1.3 Z-System Calibration**
  `Z_Tracer.lua` による毎分計算結果の構造化ログ出力。
  - `NE_MUTATION` トレースが `Value/Delta/Zone/Loc/Mask/Phase/Fog` を含むこと。
  - `TRACE_LEVEL="DEBUG"` 時のみ毎分ログ出力、本番は `INFO` に切り替え可能なこと。
  - `NE_INIT`, `NE_HEARTBEAT`, `NE_WORLD`, `NE_SCENE` の各キーが網羅されていること。
  - [ ] 検証: コンソールで `Z_TRACE` フィルタ時に全キーが出力されること。

---

## Phase 2: Logical Spawning & Setup (設計書 §3, §13)

- [x] **2.1 Atomic Teleport**
  起動モードを問わない、救護所 `(15640, 3909, 0)` への初期スポーン固定。
  - `Events.OnCreatePlayer` をトリガーとする通常ルート（B42: `OnCharacterCreationFinished` は存在しない）。
  - `NE.StartScene.ForceRun(player)` によるデバッグワープ即時実行ルート。
  - `setX/Y/Z` + `setLx/Ly/Lz` を両方セット済み。
  - ⚠️ **技術的負債 [TechDebt-01]**: `OnCreatePlayer` は既存セーブのロード時にも発火する。現状は `NE_StartSceneFinished` フラグで二重発火を防いでいるが、スタートシーン未実行のセーブ（旧バージョンで作成したもの等）をロードすると意図せずシーンが起動する。正式リリース前に「新規ゲーム判別ロジック」の実装が必要。→ **5.x** で対応予定。
  - [ ] 検証: 新規ゲーム開始時にプレイヤーが `(15640, 3909, 0)` にスポーンすること。
  - [ ] 検証: デバッグメニュー → Force Start Scene でも同座標へ移動すること。

- [x] **2.2 Gear Strip & Reset**
  初期インベントリ削除と `HospitalGown` 着用処理。
  - `inventory:clear()` で既存アイテムを全削除後、`Base.HospitalGown` を着用。
  - `Base.GasMask` と `Base.HazmatSuit` をインベントリに追加（耐久値 5% に設定）。
  - [x] 検証: `NE_SCENE / Equipment / Setup:OK` ログで装備セット完了を確認済み (2026-04-15)。

- [x] **2.3 Persistence Flags**
  `NE_StartSceneFinished` による初期化処理の二重発火防止。
  - `modData.NE_StartSceneFinished == true` ならば通常ルートで再実行しない。
  - `ForceRun` はこのガードを無視し、強制リセット + 再実行。
  - [x] 検証: `StartScene:Run:OK|Debug:false` ログで二重発火なしを確認済み (2026-04-15)。

- [x] **2.4 Cinematic Sequence**
  5ページのページ送り字幕演出と時間・カメラの制御 (設計書 §3.2)。
  - [x] `getCamera():setZoom(2.0)` + `getGameTime():setMultiplier(0.0001)` 実装済み。
  - [x] `ISModalDialog` によるページ送り UI 5ページ実装済み。
  - [x] 演出終了時 `setZoom(1.0)` + `setMultiplier(1.0)` 正常化済み。
  - [x] **残作業**: 3ページ目で足元に B42 血液 Fluid を生成（吐血演出）。
  - [x] **残作業**: 5ページ目のボタンラベルを `getText("UI_NE_Confirm")` に変更（現状は実装済みだが翻訳キー未定義）。
  - [x] 検証: `NE_SCENE / Intro / Cinematic:DONE` ログで 5 ページ演出の完走を確認済み (2026-04-15)。

---

## Phase 3: Narrative Object Injection (設計書 §3.3, §7.1)

- [x] **3.1 Dr.Hiro Generation**
  救護所エリアへの遺体 `IsoDeadBody` 生成ロジック。
  - [x] 生成起点 `(15640, 3910, 0)` + チャンクロード待機ロジック (OnTick リトライ最大 30 回) 実装済み。
  - [x] `createZombie` → 装備設定 → `IsoDeadBody.new(zombie, false)` パターン実装済み (Tutorial/Steps.lua:1096 準拠)。
  - [x] `inv:clear()` → `Base.JacketLong_Doctor` worn (`setWornItem(jacket:getBodyLocation(), jacket)`) → `Base.Shoes_Slippers` worn 実装済み (2026-04-15)。
  - [x] インベントリに `Base.FirstAidKit` 追加実装済み (2026-04-15)。
  - [x] `zombie:getDescriptor():setForename("Dr."):setSurname("Hiro")` で名前固定実装済み (2026-04-15)。
  - [x] 検証: `NE_SCENE / DrHiro / Spawn:OK|body=true|(15640,3910,0)` ログで遺体生成を確認済み (2026-04-15)。
  - [x] 検証: 白衣 (`Base.JacketLong_Doctor`) 着用・スリッパ (`Base.Shoes_Slippers`) 着用・`Base.FirstAidKit` 所持をゲーム内目視確認済み (2026-04-15)。
  - [-] 検証: 名前 "Dr. Hiro" — `SurvivorDesc.setForename/setSurname` は実装済みだが、遺体には ID カードがないためゲーム内での表示確認方法が未定。別途確認手段を検討すること。

- [x] **3.2 Key Item Assignment**
  Dr.Hiro への `B17_AccessKey` の確実な付与。
  - [x] `inv:AddItem("NOX_EVO_B42.B17_AccessKey")` 実装済み (`IsoDeadBody` 変換前のゾンビ段階で付与)。
  - [x] アイテム定義を `ItemType = base:normal` (B42 正規形式) に修正・確定済み。
  - [x] デバッグメニュー「Give B17 Access Key」オプション実装済み。
  - [x] **残作業**: 階層型リマインダーの実装 (設計書 §3.2):
    - [x] 離脱リマインド: 10タイル以上の離脱に対し `UI_NE_Card_Reminder_Dist` を最大 5 回 Say。
    - [ ] 起床リマインド: 5回離脱後も未所持なら `OnPlayerWake` で `UI_NE_Card_Reminder_Wake` を Say。
    - [ ] 永久停止: インベントリ内に `B17_AccessKey` を検知した瞬間に全リマインドをフラグ停止。
  - [x] 検証: ゲーム内で Dr.Hiro のインベントリに `B17_AccessKey` が存在し、取得可能なことを確認済み (2026-04-15)。

---

## Phase 4: Mutation Update Loop (設計書 §4.4, §4.11)

- [x] **4.1 Optimization Logic**
  「10タイル移動」または「日付変更」判定によるキャッシュ戦略の再整備。
  - `(dx²+dy²) >= 100` or `currentDay ~= lastDay` で `forceRecalc=true` 実装済み。
  - グローバルタイルキャッシュ (`NE._cacheX/Y/Z/Mult`) 実装済み。
  - [ ] 検証: 静止時に `NE_MUTATION` トレースの Zone 値が変化しないこと。

- [x] **4.2 Calculation Engine**
  環境・防護・ゾーンを統合した最終 `DeltaMutation` の正確な算出。
  - 式: `BaseRate × LocMult × MaskMult × PhaseMult × FogMult × ZoneMultiplier` 実装済み。
  - `GetZoneMultiplier`: 5 段階離散値 (2.0/1.5/1.0/0.5/0.2) 実装済み。
  - `GetPhaseMult`: Day1-15=1.0x / 16-35=1.5x / 36-49=2.5x 実装済み。
  - `FogMult`: 上限 3.0x 実装済み。
  - [ ] 検証: Zone3/屋外/マスクなし/Phase1 で Delta が **1.5** になること。
  - [ ] 検証: ルイビル Gate 中心 (Zone1) で Delta が **3.0** になること。
  - [ ] **追加作業**: 26 箇所の全震源地 (Hotspots) レジストリの実装 (設計書 §4.5)。
    - [ ] Tier 1〜3 + Origin (B17) の全座標・強度・Cap 値のテーブル化。
    - [ ] 座標付近での `NE_MUTATION` トレースによる強度・Cap 値の期待値検証。

- [ ] **4.3 Indoor Contamination System**
  室内の汚染度 `InternalContamination` の動的追跡 (設計書 §4.7)。
  - 密閉(0.3) / 半密閉(0.7) / 開放(1.0) の目標値に向かい毎分更新。
  - 開放状態: 5分で外部と同等。半密閉: 30分で 70% まで。
  - チャンクアンロード中の追いつき: `Events.LoadGridsquare` で `NE_LastUpdateTime` との差分を一括適用。
  - [ ] 検証: 窓開放後 5 分で室内の LocMult が外部と同等になること。

- [ ] **4.4 Asymmetric Zone Transition**
  車等の高速移動によるゾーン計算抜けの防止 (設計書 §4.9)。
  - 悪化（Safe→Danger）: 猶予なしで即座に `ZoneMultiplier` を更新。
  - 改善（Danger→Safe）: ゲーム内 30 分のヒステリシスを適用。
  - [ ] 検証: 高速で Zone1 に突入した際、即座に 2.0x が適用されること。

---

## Phase 5: Feedback & Awareness (設計書 §4.2, §4.12, §8.2)

- [ ] **5.1 Threshold Barking**
  変異度閾値を跨いだ際の独白 (player:say) システム。
  - トリガー閾値: 20%, 40%, 60%, 80%, 100% (上昇時) / 0% (回復時)。
  - 重複抑制: 一度安全圏 (前閾値 -1) に戻るまで再発火しない。
  - セリフ内容は設計書 §4.12 のテキストを厳守。
  - [ ] 検証: 変異度が 20% を超えた瞬間にセリフが頭上に表示されること。

- [ ] **5.2 HUD Core**
  `NE_ViralStressHUD.lua` の基本描画と変異度データのリアルタイム同期 (設計書 §8.2)。
  - `modData.NE_MutationLevel` (0-100) をゲージバーに反映。
  - 配色段階: 0-49% 緑、50-79% 黄、80-99% 橙、100% 赤点滅。
  - 50% 以上で警告演出（震え・発光）を追加。
  - ドラッグ可能な HUD 位置のセーブ/ロード対応。
  - 描画と数値取得の更新周期を分離して負荷を抑制する (設計書 §8.3)。
  - [ ] 検証: HUD バーが変異度の変化に追従すること。

- [ ] **5.3 First Symptom**
  変異度 50% での「変異性の咳」の発症と音響ヘイトの発生。
  - 50% 到達時: 咳 SE + `WorldSoundManager.addSound(radius=15)` を発火。
  - 100% 時: `radius=30` の咳音で壁越しのゾンビ AI をアクティブ化 (設計書 §4.2)。
  - 足元に B42 血液 Fluid を生成 (吐血演出)。
  - 変異度 50% 未満に回復した瞬間、咳・速度低下・視界狭窄を全解除。
  - [ ] 検証: 変異度 50% で咳が発生し、周囲ゾンビが反応すること。

---

## Phase 6: Decontamination & Items (設計書 §4.3, §6, §8.1, §15)

- [ ] **6.1 Anti-Mutation Drug**
  抗変異薬の使用ロジックと副作用の実装 (設計書 §4.3, §8.1.1)。
  - 変異度を 40〜60% 削減。最大 HP の 30% を即座に削る。
  - 激しい眩暈（パニック・吐き気ムード強制付与）+ 一時的な持久力大幅低下。
  - `NE_MutationLevel < 10%` での使用は即死ルート判定。
  - アイテム ID: `NOX_EVO_B42.NE_AntiMutantDrug`。
  - [ ] 検証: 使用後に変異度が 40-60% 削減され、HP が 30% 減ること。
  - [ ] **NE-セレム (Serum) の実装** (設計書 §8.1.3):
    - [ ] `addXP` メソッドを用いた、バニラ互換のスキルレベル向上ロジック。
    - [ ] 重要コンテナおよび SWAT からの稀少ドロップ設定。
    - [ ] 検証: 使用時にスキル経験値が加算され、既存のレベル進捗と矛盾しないこと。
  - [ ] **追加作業**: B17 アクセスキーと 4 つの変異核 (Alpha~Delta) の完全実装と紛失防止ガード。
    - [ ] 紛失緩和（**`CantBeDropped` は不採用**。ワールド配置・破壊耐性等で担保）。
    - [ ] 各サンプル（バイアル）が March Ridge, Riverside, Brandenburg, Rosewood の拠点にあることを保証。

- [ ] **6.2 Contamination Retardant**
  汚染抑制剤（30分 ΔMutation ゼロ固定）の実装 (設計書 §8.1.2)。
  - 服用後 30 分間 `DeltaMutation` を 0 に固定する。
  - HUD に残り時間タイマーを表示する (§8.2)。
  - アイテム ID: `NOX_EVO_B42.NE_ContaminationRetardant`。
  - [ ] 検証: 服用後 30 分間 `NE_MUTATION` の Delta が 0 であること。

- [ ] **6.3 Bleach Decontamination Actions**
  漂白剤・散布器・除菌手榴弾の浄化アクション群 (設計書 §6.1〜6.4)。
  - `Base.Bleach` の床散布（Pour）: 1×1 タイルを一定時間浄化。
  - 除菌噴霧器: 扇形 3×5 タイルを散布。
  - 除菌手榴弾: 半径 5 タイル即時リセット + 10 分間残留ガス（ΔMutation に -2.0 ボーナス）。
  - 浄化タイルは一定時間、外部汚染の再流入を遮断する。
  - [ ] 検証: 漂白剤散布後にそのタイルでの Delta が低下すること。

- [ ] **6.4 Gas Mask Filter Lifecycle**
  フィルター寿命と防護性能の分離管理 (設計書 §4.10)。
  - マスク ModData `NE_FilterLife` (0〜100%) を追加。
  - Zone 1〜3 滞在中、毎分 `NE_FilterLife` を消費（Zone 1 ほど消費大）。
  - `NE_FilterLife = 0` → `MaskMult` を 0.1 → 0.8 へ移行し警告 SE を発火。
  - コンテキストメニューから「交換用フィルター」で 100% 回復。
  - [ ] 検証: Zone1 滞在でフィルターが消耗し、0% で防護性能が落ちること。

- [ ] **6.5 Crafting Recipes**
  除菌装備とフィルターのクラフトレシピ定義 (設計書 §6.2)。
  - `NE_Recipes.txt` に除菌噴霧器・除菌手榴弾・交換用フィルターのレシピを追加。
  - [ ] 検証: クラフトメニューから各アイテムが作成できること。

---

## Phase 7: Mutant Ecosystem — Core (設計書 §5.1〜5.6)

- [ ] **7.1 Spawn Classification & Tint**
  6 種ミュータントの確率判定と Tint 適用 (設計書 §5.1)。
  - `ZombRand(100)` で 6 種（スキッター/タンク/シュリーカー/バースター/ストーカー/トラッカー）に分類。
  - 種別ごとの RGB 値を `Visual:setTint` で適用。
  - 種別は `zombie:setVariable("NE_MutantType", "...")` で軽量保持。
  - [ ] 検証: Zone2 以内でゾンビの色が変化すること。

- [ ] **7.2 Skitter & Tank**
  - スキッター: `setCrawler(true)` で車両下を通過可能。攻撃ヒット時 25% 確率で転倒。
  - タンク: HP 倍率アップ・耐火。
  - [ ] 検証: スキッターが車両下を潜り抜けること。

- [ ] **7.3 Shrieker (シュリーカー)**
  3 フェーズ咆哮ロジック (設計書 §5.5)。
  - Anticipation 1.5秒、Execution: 半径 50 タイル誘導、Recovery。
  - [ ] 検証: 咆哮後に半径 50 タイルのゾンビが集結すること。

- [ ] **7.4 Burster (バースター)**
  死亡時ガス放出と隣室伝播 (設計書 §5.7.3)。
  - 死亡時に `IsoThickFog` を生成し半径 3 タイルに拡散。
  - **換気依存の FadeSpeed**: ターゲット座標の部屋の「密閉・半密閉・開放」状態に応じて、ガスの持続時間を増減（窓全開時は 2.0x の速度で消散）。
  - [ ] 検証: 窓を閉めた室内ではガスが長時間滞留し、窓を開けると早く消えること。

- [ ] **7.5 Stalker & Tracker**
  - ストーカー: 無音接近・背後強襲。
  - トラッカー: 多層ブレッドクラム追跡 (設計書 §5.5.2)。
    - [ ] フェーズ 1: **メタ・トラッキング**: ロード範囲外の個体をチャンク単位で仮想移動。
    - [ ] フェーズ 2: **パン屑追跡**: 10 タイル移動ごとの座標スタック（上限 30 件）の参照。
    - [ ] 血汚れ (`HumanVisual:getBlood/Dirt`) による感知距離の最大 2.0x 補正。
  - [ ] 検証: 建物内に逃げ込み、ドアを閉めてもトラッカーが経由タイルを辿って到達すること。

- [ ] **7.6 AI Optimization**
  タイムスライス・距離階層最適化 (設計書 §5.6)。
  - `onlineID % 30` でヘビー処理を間引き。
  - 距離に応じて Full/Light/Native AI に切り替え。
  - [ ] 検証: 変異種 20 体以上でも FPS が許容範囲内であること。

---

## Phase 8: Mutant Ecosystem — Advanced (設計書 §5.7, §10.1)

- [ ] **8.1 Vertical Space Handling**
  B42 の Z 軸を活用した立体移動対応 (設計書 §5.7.1)。
  - スキッター: 隙間経路を経由した奇襲。
  - トラッカー: 階段待ち伏せ分岐。
  - [ ] 検証: スキッターが地下への経路を使って接近すること。

- [ ] **8.2 Carrier Link (群れ情報共有)**
  変異種間の索敵情報同期 (設計書 §10.1)。
  - トラッカー/シュリーカーで近傍変異種のターゲット座標を共有。
  - プレイヤー変異度が高いほど感知距離・攻撃速度が上昇。
  - [ ] 検証: シュリーカー咆哮後に周囲の変異種がプレイヤーに向かうこと。

- [ ] **8.3 Optional: Mutant Livestock**
  家畜への変異判定 (設計書 §5.7.2, オプション)。
  - 家畜に確率で変異付与、変異肉摂取で変異度 +30。
  - [ ] 検証: 変異家畜の肉を食べると変異度が増加すること。

---

## Phase 9: Environment & Visual Effects (設計書 §4.9, §4.7)

- [ ] **9.1 Zone-Based Post-Processing**
  ゾーン別カラーコレクション (設計書 §4.9.1)。
  - Zone1: `(0.15, 0.35, 0.1)` 深緑濃霧 + 色収差。
  - Zone2〜5: 段階的な彩度低下。
  - [ ] 検証: Zone1 進入時に画面が深緑に変化すること。

- [ ] **9.2 Spore Emitter & Contamination Fog**
  胞子粒子とボリュメトリックフォグ (設計書 §4.9.2)。
  - Zone 3 以上で `ParticleDensity = BaseCount × Toxicity × 2.0`。
  - Zone 1 では昼間でも有効視界 30 タイル以内。
  - [ ] 検証: Zone2 付近で空気に胞子が漂うパーティクルが見えること。

- [ ] **9.3 Indoor Contamination Visual Sync**
  室内汚染ビジュアルとデトックス可視化 (設計書 §4.9.3)。
  - `InternalContamination` 上昇に伴い緑色の霞を室内に滲ませる。
  - 除菌範囲内では汚染演出を一時リセット。
  - [ ] 検証: 室内に滞在し続けると霧が濃くなること。

- [ ] **9.4 Vegetation Decay & Ground Decals**
  植生劣化と地表デカール (設計書 §4.9.4)。
  - Zone 2 以内の植生を劣化質感に上書き。
  - 震源地半径 5 タイル内に赤黒色デカールを生成。
  - [ ] 検証: 震源地付近の地面が赤黒色になっていること。

- [ ] **9.5 B17 Origin Special Effects**
  地下最深部の専用演出 (設計書 §4.9.5)。
  - B10〜B17: 全人工光源の照射距離を 80% カット。
  - [ ] 検証: B17 地下で懐中電灯の届く距離が大幅に短くなること。

---

## Phase 10: Evolution System (設計書 §9)

- [ ] **10.1 Day Milestone Distribution**
  生存日数マイルストーンでの EP 付与・デトックス (設計書 §9.1)。
  - Day 10/20/30/40 で EP 付与 + 変異度 -25.0 の自浄作用。
  - `NE_LoreManager.lua` 経由で本能テキストを表示。
  - [ ] 検証: Day 10 到達時に EP が付与され、変異度が -25 されること。

- [ ] **10.2 Evolution UI**
  EP 消費メニューと 4 特性選択 (設計書 §9.2, §9.3)。
  - `NE_StartSceneFinished` ガード + 320×280 メニュー。
  - 4 特性: MUSCLE / FIBER / LUNG / OPTICAL。
  - 選択 or「緊急変異度回復」の 2 択。
  - [ ] 検証: EP 消費で特性が `ModData` に保存されること。

- [ ] **10.3 Awakening (極限覚醒)**
  変異度 100% 初回到達時の救済処理 (設計書 §9.4)。
  - 1 セーブ 1 回限り: 周囲ゾンビ処理 + 変異度大幅減 + EP 付与。
  - 2 回目以降は救済なし。
  - [ ] 検証: 初回 100% で救済が発動し、2 回目は発動しないこと。

- [ ] **10.4 Evolution Metabolic Cost**
  進化選択時の代謝リバウンド (設計書 §9.1)。
  - 選択直後: 空腹・渇き・疲労の大幅増加。
  - [ ] 検証: 特性選択直後にステータスが大きく悪化すること。

---

## Phase 11: World Events & Swarm Intelligence (設計書 §10, §11)

- [ ] **11.1 Outbreak Surge**
  日数別の強化波動 (設計書 §10.3)。
  - シナリオ: Day 10/20/30/40 に増大する強襲をスケジュール。
  - `NE_MetaSoundManager` によるメタサウンドで自然誘導。
  - [ ] 検証: Day 10 に強化された群れが出現すること。

- [ ] **11.5 Dynamic Decay (動的廃墟化)** (設計書 §10.4.B)
  チャンクロード時のリアルタイム環境破壊。
  - アルゴリズム: 生存日数と震源地距離に比例した確率判定 (`OnGridsquareLoaded`)。
  - スロットリング: 高速移動時（車等）は計算をスキップする負荷対策。
  - [ ] 検証: 長期生存後の世界で、放置された建物の壁や窓が自然破壊されていること。

- [ ] **11.2 Spore Storm**
  濃霧時の世界バフ (設計書 §10.2)。
  - 濃霧発生時: 全ゾーンの `BaseRate` を 2.5 倍 / 変異種の速度上昇 / 視界 -30%。
  - [ ] 検証: 濃霧天候時に `NE_MUTATION` の Delta が 2.5 倍になること。

- [x] **11.3 Phase Shift Trigger**
  フェーズ遷移イベントのフック (設計書 §11.1)。
  - [x] `NE_PhaseShiftTrigger = true` フラグの設定実装済み (`NE_WorldManager.lua`)。
  - [x] Phase 1/2/3/4 の遷移判定と `NE_Phase` 書き込み実装済み。
  - [ ] **残作業**: `NE_PhaseShiftTrigger` を読んで遷移演出・本能テキストを発火するリスナー。
  - [ ] 検証: Day 16 到達時に Phase 2 遷移の本能テキストが表示されること。

- [ ] **11.4 AI & Fog Performance Guard**
  大規模 AI とフォグの負荷制限 (設計書 §10.4)。
  - スクリプト AI 上限設定 / フォグ更新間引き。
  - [ ] 検証: 変異種 30 体以上のシーンで FPS が 30 以上を維持すること。

---

## Phase 12: Narrative & Lore (設計書 §9.1, §3)

- [x] **12.1 LoreManager — Brain Announcements**
  `NE_LoreManager.lua` による脳内アナウンス (設計書 §14.4)。
  - 特定日数・変異閾値到達時に画面上部に「本能テキスト」を表示。
  - [ ] 検証: 設計書 §9.1 の各日程テキストが表示されること。

- [x] **12.2 Secret Report Lore Integration**
  Dr.ヒロの遺志と誘導を機密書類 (`NE_SecretReport`) へ集約 (設計書 §7.1)。
  - [x] `VoiceLog`案を廃止し、4つの鍵の在処を示す誘導書類テキストを `IG_UI.json` に定義済み。
  - [ ] 機密書類を読むための専用 UI (Narrative Reader) の実装。
  - [ ] 検証: 報告書を読むことで March Ridge 等の座標ヒントがプレイヤーに提示されること。

---

## Phase 13: EndGame (設計書 §7, §11.1)

- [ ] **13.1 51-Day Hard Deadline**
  51 日目（午前 0 時）の空爆と強制浄化イベント (設計書 §7.3)。
  - [x] 生存日数 51 日 0:00 到達時のトリガーロジック (`NE_WorldManager.lua`)。
  - [ ] 扉未開放時の自動「浄化ルート」移行シークエンス。
  - [ ] Day 45 からの「終末の予兆」本能テキスト表示。
  - [ ] 検証: 51 日目 0:00 に到達した瞬間、空爆警告と演出が開始されること。

- [ ] **13.2 B17 Terminal & Integrated Quest Item System**
  最深部端末への到達と解錠プロセスの完遂。
  - [ ] **Master Key + 4 Mutation Nuclei (Samples)** の全 5 アイテムを所持時にのみ扉を開放可能にする。
  - [ ] 不足しているアイテムがある場合の「アクセス拒絶」警告メッセージ (§7.5)。
  - [ ] 17階最深部でのサンプル提出・解析シーケンス。

- [ ] **13.3 3 Branded Endings & Final Hesitation**
  浄化 / 共生 / 破滅 の 3 分岐と「逡巡」ステップの実装 (設計書 §7.4, §7.6)。
  - [ ] **最終確認演出：逡巡 (The Final Hesitation)**: 分岐クリック時に画面暗転 + 各結末の覚悟を問う問いかけ (`IGUI_NE_Ending_X_Confirm`)。
  - [ ] UI 操作: 小さく表示される [YES] で結末確定、[NO] で前の選択画面へ戻る。
  - [ ] 結末確定時: 各結末に対応した閃光VFX (白/深緑/赤緑) と、未解決の災厄の終結処理。
  - [ ] **終局後の記録 (Survival Record)**: クリア後の暗転中に `1_Record`〜`3_Record` を静かに表示。
  - [ ] プレイ継続性の制御: 「浄化」「共生」時はワールド情報を更新して生存続行。「破滅」時は `player:Kill()` (GameOver)。
  - [ ] 検証: [NO] を選択して別のエンディングを選び直せること。
  - [ ] 検証: 「生存記録」のテキストが各分岐に対応した正しい Key から呼び出されていること。

---

## Phase 14: Sandbox & Distribution (設計書 §12, §17)

- [ ] **14.1 B42ModOptions Integration**
  `PZAPI.ModOptions:create("NOX_EVOLVED", ...)` によるゲーム内オプション統合 (設計書 §2.2, §12)。
  - 難易度プリセット 4 種 (STANDARD / EASY EVOLUTION / TRUE HELL / POTATO PC)。
  - 個別キー: `MutationBaseRate`, `ExpansionRate`, `IndoorSealedMod` 等を露出。
  - [ ] 検証: ゲーム内オプションメニューに NOX 設定項目が表示されること。

- [ ] **14.2 Item Distributions**
  施設・ゾンビ別のアイテム出現率定義 (設計書 §17)。
  - `NE_Distributions.lua` (server): 病院・軍事・倉庫に薬品・フィルターを注入。
  - 変異種撃破ドロップ: トラッカー → テープ / タンク → 破損フィルター。
  - [ ] 検証: 病院施設でフィルターが確率でスポーンすること。

- [x] **14.3 Challenge Mode — [COMPLETED]** (2026-04-17)
  `NE_HyperErosion.lua`（LastStand）による超加速侵食チャレンジ (設計書 §13)。
  - [x] **B42 対応：7月開始の強制適用** — `OnInitWorld` / `AddSandboxOptions` / `OnGameStart`（`getGameTime():setMonth` 補正）。
  - [x] **サーバーサイド侵食生成（10YL互換）** — `NE_HyperErosionManager_Server.lua` の `Events.LoadGridsquare` と **5層劣化**（蔦・草・落ち葉・屋根・ゴミ）。
  - [x] **導線設計：博士のリマインダー強化** — 離脱リマインド最大 **5** 回＋起床時 **`UI_NE_Card_Reminder_Wake`**（JSON サフィックス `_Wake`）、離脱用 **`UI_NE_Card_Reminder_Dist`**（`_Dist`）。
  - [x] **バグ修正：二重スポーンと nil エラーの根絶** — スタートシーン／遺体まわりの API 整理、`NE_PlayerManager.lua` の BOM 起因 SEVERE 解消等。
  - `MutationBaseRate=0.3`, サンドボックス強制上書き、初期変異度 20%。
  - チャレンジ専用翻訳キー (`Translate/.../Challenge.json`) の追加。
  - [ ] 検証: チャレンジ選択時に変異度が 20% で開始すること。

---

## Phase 15: External Integration — SWAT (Bandit V2) (設計書 §10.4.C)

- [ ] **15.1 SWAT Squad Spawning**
  `Bandit V2` エンジンを利用した掃討部隊の定期的投入。
  - スケジュール: ゲーム内時間 24〜48 時間ごとに 1 スクワッド (3〜8人) を生成。
  - 重複制限: 同一エリアに存在する SWAT は最大 1 スクワッドに制限し負荷を抑制。
  - [ ] 検証: 指定された周期で SWAT 部隊がスポーンすること。

- [ ] **15.2 Tactical Advance & Mutation Death**
  隊員の装備設定と汚染地帯への進軍ロジック。
  - 装備: ガスマスク/軍用装備を付与。ただし NBC 完全防護ではない設定。
  - 進軍ターゲット: ホットスポット中心地（Origin）へ向けて `pathfind`。
  - 持命: 極限汚染（Toxicity 1.0）およびマスク寿命により、一定時間滞在後に「体内変異死」を自動発火。
  - [ ] 検証: 進軍中の SWAT 隊員が汚染により死亡し、その場に遺体が残ること。

- [ ] **15.3 Delayed Reincarnation (再誕)**
  隊員の死亡とゾンビ化の時間差処理。
  - キューイング: SWAT 死亡時に座標と時刻を `ModData` に保存。
  - 発生: 死亡から 1 時間経過後の再ロード時に、SWAT 装備の特殊ゾンビとしてスポーン。
  - [ ] 検証: 死亡した隊員が、即座ではなく一定時間後にゾンビとして起き上がること。

- [ ] **15.4 Hound AI — Collective Sensing**
  部隊単位での超感覚および執脳な追撃。
  - 感知共有: 1 人がプレイヤーを検知（半径 40 タイル）すれば部隊全員がターゲットを共有。
  - 猟犬ロジック: 視線が切れても 20〜30 秒間はプレイヤーの最新座標に向けて追跡を継続。
  - [ ] 検証: 壁の裏に隠れても、SWAT 部隊が直前の位置まで正確に追いかけてくること。

---

## Phase 16: External Integration — Airstrikes (HEF) (設計書 §10.4.A)

- [ ] **16.1 Targeting & Offset Logic**
  `HelicopterEventExpansionFramework` と連携した動的な爆撃座標算出。
  - 安全確保: プレイヤーの現在座標から 15 タイル以上のオフセットを強制したターゲット選定。
  - 重点区域: 汚染半径の 5 倍圏内、かつプレイヤー周囲 50〜200 タイル圏内を優先。
  - 除外設定: B17 Origin (震源地) および重要アイテムコンテナ設置マスの保護。
  - [ ] 検証: 爆撃がプレイヤーの直上ではなく、周囲の廃墟化を促す形で発生すること。

- [ ] **16.2 Non-Fire Destruction & Debris**
  延焼を伴わない物理的な環境破壊ロジック。
  - 破壊対象: `Remove` 命令による壁・窓・ドア・家具の削除。
  - 床の保護と置換: `Replace` 命令による床スプライトの「焦げ跡・瓦礫」への置換（落下死の防止）。
  - エフェクト: 延焼判定のない専用爆発パーティクルの再生。
  - [ ] 検証: 爆撃後のエリアが火災にならず、スプライトが瓦礫へ置換されていること。

- [ ] **16.3 Audio-Visual Cues (空爆予兆)**
  爆撃開始前のナラティブな警告演出。
  - サイレン音の再生および画面の微細な揺れ。
  - 「空爆が開始される」旨の `player:Say` または本能テキストの表示。
  - [ ] 検証: 着弾前にプレイヤーが予兆を察知できること。

---

## Phase X: Debug, QA & Release (設計書 §16, §18)

- [-] **X.1 Debug Control Panel**
  `NE_DebugMenu.lua` の拡充 (設計書 §16.2)。
  - [x] コンテキストメニュー「[Debug] NOX: EVOLVED」サブメニュー展開 (`parentMenu:addSubMenu` パターン) 実装済み。
  - [x] 変異度設定サブメニュー (Set Mutation Level) 実装済み。
  - [x] 時間設定サブメニュー (Set Day) 実装済み。
  - [x] テレポートサブメニュー (Teleport) 実装済み。
  - [x] 「Give B17 Access Key」オプション実装済み (`NE.Debug.GiveCardKey`)。
  - [x] `ForceStartScene` オプション実装済み。
  - [x] 検証: BuildMenu → addOption → addSubMenu → MutSubMenu/DaySubMenu/TpSubMenu の全 OK ログ確認済み (2026-04-15)。
  - [x] **残作業**: EP・フェーズ・フィルター寿命の直接操作。
  - [x] **残作業**: 症状トグル / マイルストーン強制発火。
  - [ ] **残作業**: `AI Inspector`: キャリアリンク状態・追跡パスの可視化。
  - [ ] 検証: デバッグメニューから全パラメータが操作できること。

- [ ] **X.2 Consistency Audit**
  起動時の整合性監査 (設計書 §16.4)。
  - セーブデータのマイグレーション検証。
  - MOD 干渉チェック（`NE_MutationLevel` の上書き検出）。
  - **[TechDebt-01] 新規ゲーム判別ロジックの実装**: `Events.OnCreatePlayer` は既存セーブロード時にも発火するため、B42 で新規ゲームと既存ロードを正確に区別する手段が必要。候補: `getGameTime():getNight()` や `NE_SurvivalDays == 1` との複合判定、またはワールド生成UIDのハッシュ比較。現状は `NE_StartSceneFinished` フラグで代替しているが、MOD初導入セーブでの誤発火リスクがある。
  - [ ] 検証: 旧バージョンのセーブデータがロードエラーなく動作すること。
  - [ ] 検証: [TechDebt-01] 旧セーブロード時にスタートシーンが発火しないこと。

- [ ] **X.3 Pre-Release Checklist**
  公開前の最終確認項目 (設計書 §18.3)。
  - パス大文字小文字の一致確認。
  - 全翻訳キー網羅確認 (`Translate/JP/`)。
  - アイテム ID 表記ゆれの解消: `NOX_EVOLVED.AntiMutationDrug` vs `NE_AntiMutantDrug` → §15 準拠に統一。
  - `NE_DebugTools.lua` / `NE_Debug.lua` ファイル名不一致の解消。
  - Zone1/Phase3/防護なしで崩壊時間が仕様の約 100 分以内であること。
  - [ ] 検証: 全チェック項目をパスすること。
