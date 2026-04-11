# Project "NOX: EVOLVED" - Master Design Document (Build 42 Standard)

> [!IMPORTANT]
> **最終更新**: 2026-04-09
> **対象バージョン**: Project Zomboid Build 42 (42.16.x +)
>   **非公式Wiki**　https://pzwiki.net/wiki/Unofficial_JavaDocs_(Build_42)
---

## 1. プロジェクト概要
- **コンセプト**: 1993年、ノックス・イベントの「終焉の変貌（環境適応・進化型）」を描くハードコアMOD。既存の生存戦略が通用しない、進化した**ウィルス**による世界の変質と個体の進化を描く。
- **期間**: 50日間の生存と進化。50日目に軍による最終浄化（空爆）が実行される。
- **目標**: ルイビル臨時救護所から、感染源を目指す大遠征。50日目の終末を生き延び、未定の目的地へ到達する。
- **開発環境**: Project Zomboid Build 42 / Antigravity Framework / Lua 5.1 (B42 optimized)
- **リソース方針**: グラフィックは自作せず、既存MOD（Brita, EHE等）のアセットをロジックで制御・置換する。
- **MOD ID**: `NOX_EVOLVED_3`

## 2. 開発環境とディレクトリ構造 (B42 Standard)

### 2.1 ディレクトリ構成
Build 42 のバージョン管理機能に基づき、以下の構造を厳守する。
```
NOX_EVOLVED_3/
├── mod.info           (検出用ダミー)
├── poster.png
└── 42/                (Build 42 専用データ)
    ├── mod.info       (B42正式メタデータ: modversion=2)
    ├── media/
    │   └── lua/
    │       ├── client/
    │       ├── server/
    │       └── shared/
    └── poster.png
```

### 2.2 設定システム (PZAPI)
- **基盤**: `B42ModOptions` (Workshop ID: 3386860561) を利用。
- **実装例**: `PZAPI.ModOptions:create("NOX_EVOLVED", "NOX: EVOLVED")` を使用して、ゲーム内オプションメニューに詳細設定を統合する。


### 2.1 初期ロケーション
- **座標**: `15640, 3909, 0`（ルイビル近郊の指定地点）
- **実装ファイル**: `NE_StartScene.lua` (client)

### 2.2 初期シチュエーション（シネマティック・プロローグ）
プレイヤーがポイント割り振りウィンドウを閉じた瞬間、ゲームが一時停止し、画面中央にストーリーUIが表示される。

#### 1. 演出とカメラ
- **カメラ**: 開始時に **Zoom 2.0 (最大近傍)** まで寄り、臨場感を高める。
- **一時停止**: ストーリーUIが表示されている間、ゲーム内時間は完全に停止する。

#### 2. ストーリーUI（ページ送り形式）
| ページ | テキスト内容 (要約) | 連動演出 |
| :--- | :--- | :--- |
| **1** | 気絶からの目覚め、身体の異常。 | 字幕表示 |
| **2** | 隣に横たわる Dr.Hiro への気づき。 | 字幕表示 |
| **3** | **激し咳き込みと吐血。** | **Trauma演出 (床に血痕) + 嘔吐音** |
| **4** | 空港移送失敗の困惑と、軍施設への旅の決意。 | 字幕表示 |
| **5** | Dr.Hiro を調べるよう誘導。 | ボタンが「適応完了」に変化 |

#### 3. 自由行動の開始
- UIを閉じると、カメラが **Zoom 1.0 (標準)** へ戻り、時間が動き出す。
- **リマインダー**: カードを拾わずに 10 タイル離れると、Dr.Hiroの遺体を調べるよう独白が発生。

### 2.3 初期アイテム・装備（および配置NPC）
`NE.InitialEvent.setupInitialState` で実行。

| カテゴリ | 対象・アイテム | 詳細 |
| :--- | :--- | :--- |
| **初期装備** | `Base.HospitalGown` | **プレイヤー着用状態**。他は全削除。 |
| **初期所持品** | `Base.GasMask`, `Base.HazmatSuit` | インベントリ内（耐久5%）。 |
| **隣の死体** | **Dr.Hiro (研究員)** | `(15640, 3910)` に生成。白衣と青スクラブ着用。 |
| **重要アイテム** | `B17_AccessCardKey` | **Dr.Hiroの所持品として配置**。 |

- **カードキーの役割**: ゴール地点（地下17階）へのアクセス権限を証明する唯一の手段。
- **Dr.Hiro**: プレイヤーを実験体（サンプル）として扱っていた研究員。

---

## 3. ファイル構成 (Project Tree)

```
mods/NOX_EVOLVED_3/
├── mod.info
├── poster.png                        # MOD選択画面の画像
├── media/
│   ├── scripts/
│   │   ├── NE_Items.txt              # アイテム・漂白剤燃料・消耗品定義
│   │   └── NE_Recipes.txt            # 除菌放射器リフィル等のレシピ
│   ├── textures/
│   │   ├── NE_HUD_Main.png           # 汚染度計・ストレスHUD
│   │   └── NE_Overlay_Toxic.png      # 画面端の毒霧オーバーレイ
│   ├── sound/
│   │   └── scripts/NE_Sounds.txt     # 咳・バイタル音・システム警告SE定義
│   └── lua/
│       ├── shared/
│       │   ├── NE_Core.lua           # 最重要：汚染計算・グローバル定数
│       │   ├── Definitions/
│       │   │   └── NE_MutantStats.lua # 各種変異体の性能・デバフ定数管理
│       │   └── Translate/
│       │       └── JP/
│       │           ├── UI_JP.txt      # 汎用UI・ハローノート文字列
│       │           ├── ItemName_JP.txt # アイテム名
│       │           └── Challenge_JP.txt # チャレンジタイトル・説明文
│       ├── client/
│       │   ├── NE_StartScene.lua     # 病院での導入・初期配布・セリフ
│       │   ├── NE_PlayerManager.lua  # クライアント側プレイヤー更新
│       │   ├── NE_ViralStressHUD.lua # 縦型汚染度ゲージ描画 (UI)
│       │   ├── NE_Environment.lua    # 毒霧の視覚効果・環境デバフ
│       │   ├── NE_EvolutionUI.lua    # 進化選択メニュー
│       │   ├── NE_BleachActions.lua  # 漂白剤使用（体・床）のAction
│       │   ├── NE_SanitizerLogic.lua # 火炎放射器フック / Erosion除去
│       │   ├── NE_EndingUI.lua       # エンディング分岐・最終ログ出力
│       │   ├── NE_LoreManager.lua    # 本能テキスト・脳内アナウンス
│       │   ├── NE_DebugTools.lua     # 開発用：汚染度・日付・Hotspot操作
│       │   └── LastStand/
│       │       └── Challenge_NOX_EVOLVED.lua # チャレンジモードの登録
│       └── server/
│           ├── NE_WorldManager.lua   # 日数(生存時間)の永続化・フェーズ管理
│           ├── NE_MutantManager.lua  # ゾンビのスポーン時・更新時属性付与
│           ├── NE_EndGame.lua        # Airstrike(空爆)発生・最終セクター管理
│           └── NE_SandboxDefaults.lua # サンドボックス設定の整合性強制
```

---

## 4. コアシステム：NE_Core.lua (shared)

### 4.1 グローバル定数 (`NE.Config`)
```lua
NE.Config = {
    BaseRate = 0.05,      -- 1分ごとの基礎上昇率 (10倍速)
    MaxPollution = 100,
    RecoveryRate = -0.005,-- 1分ごとの自然回復率
    SleepMult = 5.0,      -- 睡眠中の回復倍率
    LocMult = { Outdoor = 0.75, ResearchFacility = 1.5, GeneralIndoors = 1.0 },
    MaskMult = { GoodMask = 0.1, BrokenMask = 0.8, NoMask = 3.0 }, -- BodyLocation: Mask/FullHat
    ExpansionRate = 80.0
}
```

### 4.2 身体症状とペナルティ
汚染度（`NE_PollutionLevel`）の状態に応じ、以下の症状が発生する。

| 汚染度 | 身体症状 (`Symptoms`) | 視覚効果 (`Visuals`) |
| :--- | :--- | :--- |
| **25%** | 軽いめまい・パニック | なし |
| **50%** | 吐き気・持久力回復低下 | 視界の周縁が暗くなり始める |
| **75%** | 激しいめまい・発熱・HP微減 | **視野狭窄**: 周縁が半透明の影で覆われる |
| **100%** | **臨界**: 上記症状の激化・歩行困難 | **極度の視野狭窄**: 視界の大部分が遮蔽される |

※ 100%は即死ではないが、人外化への最終段階となる。

### 4.3 回復と独自アイテム
- **自然回復**: 安全圏（`ViralFactor = 0`）滞在時に適用。
- **睡眠ボーナス**: 睡眠中は回復速度が **5倍** に増幅。
- **抗ウィルス剤 (`NE_Antiviral`)**: 
    - 独自アイテム（アイコンは既存の薬品を流用）。
    - 汚染度を 40〜60% 減少。
    - 代償：最大HPの30%減少、激しい眩暈、一時的な虚脱。

### 4.4 負荷対策と計算精度
- **更新間隔**: ゲーム時間 **1分ごと** (`EveryOneMinute`)。移動による「無傷での汚染圏突破」を防止。
- **計算閾値**: 前回の計算地点から **10タイル以上** 移動していない、かつ **ゲーム内日付が変わっていない** 場合のみ、距離計算（ViralFactor）をスキップし、前回の結果を再利用することで CPU 負荷を最小限に抑える。

### 4.5 ウィルス震源地 (`NE.Hotspots`)
汚染源は「重要度（Strength）」を持ち、広がるスピードが異なる。

| 種別 | 強度 (Strength) | 最大強度 (Cap) | 主要ロケーション |
| :--- | :--- | :--- | :--- |
| **Tier 1 (軍事)** | 1.6 - 2.0x | **100% (1.0)** | 秘密軍事基地, ルイビル検問所, マーチリッジ |
| **Tier 2 (都市部)** | 1.0 - 1.2x | **50% (0.5)** | 各主要4都市の中心、ルイビル市街地 |
| **Tier 3 (密集地)** | 0.4 - 0.9x | **25% (0.25)** | 病院, モール, 警察署, トレーラーパーク, 主要交差点 |

*全26箇所のホットスポットがマップ全域に定義されている。*

### 4.3 支配域の拡大
- **拡大率**: `NE.ExpansionRate = 80`（標準設定）
- **計算**: `radius = (currentDay - 1) * 80 * hotspot.strength + 1.5` (1日目から 3x3 の範囲をカバー)
- **汚染係数** (`CalculateViralFactor`): 
    - 2D平面距離で強度を計算し、`cap` でクランプ。
    - **垂直減衰**: ホットスポット階との差 `n` に対し、`intensity * 0.8^n` で最終強度を算出。
    - 全震源地の影響の中から、最も高い値を採用する。

- **結合（Convergence）**: Day 25 前後に軍事拠点と都市部の汚染域が連結し、マップの主要路が遮断される。


### 4.4 主要関数一覧
| 関数 | 概要 |
| :--- | :--- |
| `NE.GetCurrentDay()` | ModData `NE_SurvivalDays` を返す (未設定時は 1) |
| `NE.CalculateViralFactor(x, y, z)` | 座標(3D)の汚染係数(0 to 1) と最短距離(2D)を返す |
| `NE.GetViralFactor(x, y, z)` | 上記を呼びキャッシュを更新（予定） |
| `NE.PurifyAt(x, y, radius)` | 指定範囲の動的ホットスポットを除去 |
| `NE.InitWorldData()` | ワールドModDataの初期化 |
| `NE.InitPlayerData(player)` | プレイヤー初期化（V2用フラグ管理） |
| `NE.SkipTime(hours)` | デバッグ用時間スキップ |

---

## 5. 変異個体の定義 (NE_MutantManager.lua / server)
ウィルスによる再感染（Reinfection）の過程で、個体は身体能力の向上だけでなく、稀に特殊な「特性（アビリティ）」を獲得する。

### 5.1 出現条件
- **生存5日目以降**から発生.
- **発生確率**: `baseMutationChance(25) × viralFactor × 2`。支配域中心で最大50%。
- **種別判定**: `ZombRand(100)` -> 0-19: 斥候, 20-39: エリート, 40-99: 再感染個体

### 5.2 変異個体ステータス（実装値）

| 個体名 | setSpeedType | HP (setHealth) | 特殊ロジック |
| :--- | :--- | :--- | :--- |
| **斥候 (Scout)** | `1` (Sprinter/超高速) | `0.7` (低耐久) | `setCrawler(true)`, `setCanCrawlUnderVehicle(true)`, `setCanWalk(false)`。60tick毎に血痕（粘液代用）を生成。 |
| **エリート (Elite)** | `3` (Slow Shambler/鈍重) | 擬似強靭 | **[API制約回避: 強靭化]**: `setHealth` 値がエンジンに上書きされるため、`OnWeaponHitCharacter` イベントをフックし、対象がエリート(ModData判別)の場合は `zombie:setHealth(zombie:getHealth() + (damage * 0.66))` のように体力を足し戻して被ダメージを実質 1/3 に減衰させて高HP(350相当)を実現。<br>**[API制約回避: 耐火]**: `setNeverBurn` の不具合対策として、`OnZombieUpdate` で対象を監視し `zombie:isOnFire()` の瞬間に `zombie:StopBurning()` を実行（パフォーマンス維持のため、非変異体はModDataチェック後即return必須）。<br>軍用装備 (`Hat_Army`, `Vest_BulletArmy`) 自動装着。30%確率でGasMask追加。 |
| **再感染個体 (Reinfected)** | `2` (Fast Shambler) | `2.0` (HP 200相当) | `OnZombieDead` 時、死体を中心に半径3タイル内のプレイヤーの汚染度を即時 `+10`。`"VIRAL BURST!"` のHaloNote表示。 |

---

## 6. 環境汚染システム (Environmental Toxicity)

### 6.1 累積汚染 (Viral Stress) — NE_PlayerManager.lua
`Events.EveryTenMinutes` で毎10分ごとに以下の計算を実行。

**計算式**: `PollutionDifference = (BaseRate × LocMult × MaskMult × PhaseMult × FogMult × ExpansionMult) or NaturalRecovery`

| 係数 | 値 | 条件 |
| :--- | :--- | :--- |
| **BaseRate** | `0.05` | 固定 |
| **NaturalRecovery** | **-0.05** | **汚染係数が 0（完全に安全な場所）にいる場合のみ適用** |
| **LocMult (場所)** | `2.0` / `0.5` / `1.0` | 屋外 / 研究・軍事施設内 / 一般家屋 |

| **MaskMult (防護)** | `0.1` / `0.8` / `3.0` | ガスマスク装着(耐久有) / 装着(耐久0) / 未装着 |
| **PhaseMult (フェーズ)** | `1.0` / `1.5` / `2.5` | Phase 1 / Phase 2 / Phase 3+ |
| **FogMult (霧)** | `1.0 + (fogIntensity × 2.0)` | 最大3倍 |
| **ExpansionMult (支配域)** | `1.0 + (viralFactor × 3.0)` | 汚染源中心で4倍 |

### 6.2 汚染段階別の影響一覧
汚染度（Viral Stress）の蓄積量に応じた具体的な数値デバフ。
※`NE_PlayerManager.lua` (10分毎) で処理。

| 段階 | 閾値 | ステータス・数値デバフ | 視覚演出 / セリフ |
| :--- | :--- | :--- | :--- |
| **Normal** | 0%〜 | 基本回復のみ / ストレス微増(`+0.01`) | 変化なし / 「空気がうまい。」(回復時) |
| **Level 1** | 10%〜 | 持久力回復速度 -10% / 疲労蓄積(`+0.001`) | 画面縁に薄い緑 / 「何か嫌な味がする…」 |
| **Level 2** | 30%〜 | 視覚の揺れ(0.1) / ストレス(`+0.05`) | 周辺視野の減退(30%影) / 「少し震えが止まらない。」 |
| **Level 3** | 60%〜 | **HP継続減少(`-0.5%/分`)** / 痛み(20) | **トンネルビジョン**(60%影) / 「胸が…肺が動かない…」 |
| **Level 4** | 80%〜 | HP減少加速(`-1.5%/分`) / パニック上昇 | 視界のさらなる狭窄 / 「視界が、暗くなっていく…」 |
| **Level 5** | 100% | **致命的崩壊**、HPの急速な減少 | 視界の低速点滅 / 「死ぬ、肺が消えていく。今すぐ洗わなきゃ！」 |

**共通・付随効果:**
- **トンネルビジョンの緩和**: 最も酷い時でも中央の40%の領域は視認可能。影の透明度は0.8とし、微かに周囲を視認できるよう調整。
- **レベル変動時の通知**: レベルが上がった時、下がった時にキャラクターが自動で独り言(Sayボタン同様)を発し、プレイヤーに警告する。


### 6.4 汚染通知 — NE_PlayerManager.lua
汚染レベルが変動した瞬間に、頭上に独り言（Barking）を表示して警告する。
- **レベル上昇時**: `"Metalic taste..."` / `"Lungs are burning!"` 等の警告。
- **レベル下降時**: `"Fresh air..."` / `"I can breathe again."` 等の安堵。
- **定時（10分毎）**: 85%以上などの極限状態では定期的に苦痛のセリフを発する。

### 6.5 環境の変質
汚染源周辺の視覚効果（毒霧・画面の変色）。実装の詳細は [18節（視覚的演出）](#18-視覚的演出) を参照。
- **描画方式**: `NE_Environment.lua` にて `ISPanel` 派生のオーバーレイを毎フレーム描画。

---

## 7. 浄化とリソース (Decontamination)

### 7.1 漂白剤：体の除菌 — NE_BleachActions.lua
- **アクション名**: `NE_WashBodyAction` (ISBaseTimedAction派生)
- **コンテキストメニュー**: `Base.Bleach` アイテムへの右クリックで `"Wash body with bleach"` が出現。
- **アニメーション**: `"Eat"` (飲む動作の流用)
- **効果**:
  - 汚染度 **-25** 回復
  - 副作用: **直接ダメージ(`-15.0 HP`)** (※最大HPの恒久的減少ではない)、痛み(40)
  - アイテム消費: 1回使用で `usedDelta -0.25`
  - セリフ: `"It burns... but the corruption is gone."`

### 7.2 漂白剤：地面の除菌 — NE_BleachActions.lua
- **アクション名**: `NE_PurifyFloorAction` (ISBaseTimedAction派生)
- **コンテキストメニュー**: `"Purify Floor"` として出現。
- **アニメーション**: `"Pour"`
- **効果**:
  - `NE.PurifyAt(x, y, 3.0)` で動的ホットスポットを浄化
  - 周囲3タイルの `removeBlood()` で血痕（粘液）を除去
  - アイテム消費: 1回で `usedDelta -0.20`（5回使用可能）
  - セリフ: `"The ground is clean... for now."`

### 7.3 除菌兵装の実装計画
- **常用：除菌噴霧器 (Sanitizer Sprayer)**
    - ベース: `Base.ChemicalSprayer` (B42)
    - ビジュアル: 青白い除菌パーティクルの放射。
    - 浄化方式: 扇形範囲（プレイヤー正面60度、半径5タイル）。`NE.PurifyAt()` を継続的に実行。
- **緊急用：除菌手榴弾 (Sanitizer Grenade)**
    - 役割: 瞬間的な広域浄化と安全圏（聖域）の生成。
    - 爆発効果: 半径7タイルの汚染を即座に 0% へリセット。
    - 残留効果: しばらくの間、青い除菌ガスが滞留し、内部のプレイヤーを回復、ゾンビにダメージを与える。

---

## 8. 最終目的地：地下17階軍事基地 (The Heart of Corruption)
Build 42 で新設されたバニラロケーションを最終目的地として活用する。

- **場所**: B42 新設の軍事基地（最寄り：Fort U.S.M.C 等）。
- **特徴**: 地下17階建て。
- **汚染レベル**: 深くなるほど `ViralFactor` が増大。B10以降は防護服無しでは数秒で致死。
- **最深部**: 「ウイルスの心臓部」が存在し、50日目のエンディング分岐が発生する。

---

## 8. カスタムHUD — NE_ViralStressHUD.lua

### 8.1 ウィルス感染度メーター (Viral Strain Gauge)
- **クラス**: `NE_ViralStressHUD` (ISPanel派生)
- **配置**: 画面左上 (x=120, y=70)、サイズ 42×210
- **デザイン**: 縦型バー (幅18 × 高さ150)。背景は極薄(α0.1)のフローティングスタイル。
- **色段階**:
  | 汚染度 | 状態表示 | 色 (R, G, B) |
  | :--- | :--- | :--- |
  | 0～24% | NORMAL | 0.5, 0.75, 0.5 (緑) |
  | 25～49% | CAUTION | 0.8, 0.8, 0.2 (黄) |
  | 50～74% | DANGER | 1.0, 0.5, 0.0 (橙) |
  | 75～100% | TERMINAL | 1.0, 0.1, 0.1 (赤) |
- **フラッシュ演出**: 汚染度が+0.1以上増加すると15tick間白く発光。
- **登録**: `Events.OnTick` で毎フレーム存在チェック、未生成なら初期化。

---

## 9. プレイヤーの自己進化 (NE_EvolutionUI.lua / NE_LoreManager.lua)
ウィルスへの暴露と「本能」の覚醒に合わせ、プレイヤー自身の肉体も環境に適応し、強化される救済措置。

### 9.1 進化の瞬間：日数別ポイント配布とデトックス
生存 **1, 5, 15, 30, 40日目** の到達時に、肉体の変貌（進化）が発生する。

| 生存日数 | 獲得ポイント | デトックス効果 | 累計P |
| :--- | :--- | :--- | :--- |
| **Day ２** | 1P | **汚染度 -25%** | 1P |
| **Day 5** | 1P | **汚染度 -25%** | 2P |
| **Day 15** | 1P | **汚染度 -25%** | 3P |
| **Day 30** | 1P | **汚染度 -25%** | 4P |
| **Day 40** | 1P | **汚染度 -25%** | 5P |

**仕様:**
- 各マイルストーンに到達した起床時（またはロード時）に判定され、一度だけ報酬が付与される。
- デトックス効果は現在の汚染度を割合で減少させ、進化の瞬間に生存を後押しする。

### 20. 進捗と報酬 (Survival Progression)
詳細は [9.1 節](#9.1-進化の瞬間：日数別ポイント配布とデトックス) を参照。
生存日数に応じたマイルストーンで、進化ポイント(EP)と汚染度の自浄作用（デトックス）を獲得できる。


- **適応対象**: 疾走(Sprinting)、筋力(Strength)、フィットネス(Fitness)、軽快(Nimble)。1Pにつき1レベル上昇。

### 9.2 進化UI
- **クラス**: `NE_EvolutionUI` (ISCollapsableWindow派生)
- **表示条件**: `NE_StartSceneFinished == true` かつ `NE_OpenEvolutionUI(points)` が呼ばれた場合。
- **ガード**: 救護所シーンが完了していない場合、関数はreturnし表示しない。
- **配置**: 画面中央、サイズ 320×280、背景α0.92。

### 9.3 適応対象
| ボタンラベル | 対象Perk | セリフ |
| :--- | :--- | :--- |
| ADAPT MUSCLE: SPRINTING | `Perks.Sprinting` | "My legs... they're screaming for more speed..." |
| RESTRICT FIBER: STRENGTH | `Perks.Strength` | "Something inside... is tearing... growing stronger." |
| ENHANCE LUNGS: FITNESS | `Perks.Fitness` | "The spores... they are fueling my breath." |
| SHARPEN NERVE: NIMBLE | `Perks.Nimble` | "I can see... their movements... clearly." |
| RESIST THE VOICES | ー | UIを閉じる（何もしない） |

- **効果音**: `"ZombieEating"` を再生。
- **HaloNote**: `"EVOLUTION: PHASE UPDATED"` を色付きで表示。
- **上限**: 各Perkレベル10でそれ以上の進化は不可。

### 9.4 突然変異トリガー — NE_LoreManager.lua
- `Events.EveryOneMinute` で毎分チェック。
- **条件**: `NE_Pollution >= 100` かつ `NE_MutatedFinalTrigger` が未設定。
- **効果**: `NE_OpenEvolutionUI(5)` で5ポイント付与。`NE_MutatedFinalTrigger = true` でフラグ設定。
- セリフ: `"THE VOICES... I CAN'T RESIST ANYMORE..."`

---

## 10. 本能（Instinct）システム — NE_LoreManager.lua
プレイヤーは単なる生存者ではなく、ウィルスの「保菌者（キャリア）」として、世界の変質を五感で察知する。

### 10.1 表示タイミング
- `Events.OnGameStart`: ゲーム開始時に1回。
- `Events.EveryHours`: 毎時間チェックし、午前9時に表示。
- **ガード**: `NE_StartSceneFinished` がtrueでなければ表示しない。

### 10.2 起承転結の「本能」タイムライン（要ローカライズ）
起床時に表示される独白メッセージ。すべて `Translate` フォルダ内のキーで管理する。

| 生存日数 | ローカライズキー | メッセージ内容の要約 (JP) | 攻略上のヒント |
| :--- | :--- | :--- | :--- |
| **Day 2** | `UI_NE_Instinct_Day2` | 咳の悪化、Dr.Hiroへの言及、軍施設への動機。 | 汚染システムの進行と初期誘導。 |
| **Day 10** | `UI_NE_Instinct_Day10` | 体の変調とウィルスの変化を感じる、空気中の胞子。 | 感染源エリアの特徴と変異体の予兆。 |
| **Day 20** | `UI_NE_Instinct_Day20` | 死までの残り日数の予感、肉体の再構築。 | 支配域拡大と汚染レベル深刻化。 |
| **Day 30** | `UI_NE_Instinct_Day30` | 思考と感覚の変容、西への欲求が強くなる。 | 汚染上昇率加速(BaseRate)の警告。 |
| **Day 40** | `UI_NE_Instinct_Day40` | 今の状況の確認後、自己解決するか軍の介入も考えられることへの気づき | タイムリミット（40日目）の提示。 |
| **Day 50** | `UI_NE_Instinct_Day50` | 限界だ。今すぐ到達しなければならないことの確信。 | 最終イベント開始の合図。 |

---

## 11. ワールド管理 — NE_WorldManager.lua (server)

### 11.1 フェーズ管理
`Events.EveryDays` で毎日更新。`getWorldAgeHours() / 24` から経過日数を算出。

| フェーズ | 日数 | 名称 | PhaseMult |
| :--- | :--- | :--- | :--- |
| **Phase 1** | 1～15日 | 平穏 | 1.0倍 |
| **Phase 2** | 16～35日 | 予兆 | 1.5倍 |
| **Phase 3** | 36～49日 | 崩壊 | 2.5倍 |
| **Phase 4** | 50日～ | 審判の日 | （EndGame処理） |

- **フェーズ遷移時**: `NE_PhaseShiftTrigger = true` でフラグを設定。

---

## 12. 最終分岐：50日目の選択 (NE_EndGame.lua / NE_EndingUI.lua)

### 12.1 50日目のトリガー
- **NE_WorldManager.lua**: 50日目に `NE_JudgementDayArrival = true` を設定。
- **NE_EndGame.lua**: `Events.EveryOneMinute` で毎分チェック。
  - `NE_SurvivalDays >= 50` または `NE_JudgementDayArrival == true` で爆撃開始。
  - 正午(12時)以降、5%確率でプレイヤー周辺に `NE_TriggerAirStrike()` を実行。

### 12.2 空爆ロジック (`NE_TriggerAirStrike`)
- プレイヤー座標から ±15 タイルのランダム地点に着弾。
- **音**: `WorldSoundManager` 半径150タイル。
- **火災**: 着弾点中心の 5×5 タイルに `IsoFireManager.StartFire(cell, sq, true, 100, 100)`。
- **ゾンビ殺傷**: 着弾点から8タイル以内 (`dx²+dy² < 64`) のゾンビを `setHealth(0)` で即死。
- **HaloNote**: `"AIR STRIKE DETECTED!"` (赤色)。

### 12.3 最終アクセス（エンディングUI起動）
- **ゴール座標**: `5569, 12432` (Military Research Facility - 地下層最深部)
- **条件**: `NOX_EVOLVED.B17_AccessCardKey` (Dr.Hiroの遺体から回収) を所持。
- **自動起動 (Proximity Trigger)**: 指定座標から半径1.5タイル以内に進入した瞬間、`NE_TriggerEndingUI = true` フラグでクライアントUIを強制起動。
- **未接近/条件未達成**: 端末へのアクセス不可。

### 12.4 エンディングUI — NE_EndingUI.lua
- **クラス**: `NE_EndingUI` (ISPanel派生)
- **サイズ**: 340×300、画面中央配置。

| 選択肢 (Label) | 内部フラグ | 対応する翻訳キー (Say内容) |
| :--- | :--- | :--- |
| **1. PURIFICATION** | `PURIFICATION` | `IGUI_NE_Ending_Purification` |
| **2. SYMBIOSIS** | `SYMBIOSIS` | `IGUI_NE_Ending_Symbiosis` (軍との永続的敵対) |
| **3. DESTRUCTION** | `DESTRUCTION` | `IGUI_NE_Ending_Destruction` |


---

## 13. カスタムアイテム — NE_Items.txt

```
module NOX_EVOLVED {
    /* 唯一の管理権限キー */
    item B17_AccessCardKey {
        Type = Normal,
        DisplayName = B17-AccessCardKey,
        Icon = IDcard,
        Weight = 0.1,
        Tooltip = Tooltip_B17_AccessCardKey
    }
}
```

---

## 14. サンドボックス強制設定 — NE_SandboxDefaults.lua (server)
`Events.OnInitWorld` でゲーム開始時に以下を強制上書き。

| カテゴリ | 設定 | 値 |
| :--- | :--- | :--- |
| **ゾンビ** | Speed | 2 (Fast Shambler) |
| | Strength | 1 (強靭) |
| | Toughness | 1 (タフ) |
| **密度** | Zombies | 2 (高密度 x1.5) |
| | PopulationStartMultiplier | 1.0 |
| | PopulationPeakMultiplier | 1.5 |
| | PopulationPeakDay | 28 |
| **時間** | StartMonth | 10 (10月) |
| | StartDay | 1 |
| **物資** | FoodLoot / WeaponLoot / OtherLoot / MedicalLoot | 2 (Extremely Rare) |
| **侵食** | ErosionSpeed | 2 (Normal) |
| | ErosionDays | 0 (進行済み) |
| | NatureAbundance | 3 (Rare) |
| **インフラ** | ElecShutModifier | 1 (0-30日以内) |
| | WaterShutModifier | 1 (0-30日以内) |

---

## 15. チャレンジモード — Challenge_NOX_EVOLVED.lua (client/LastStand)

### 15.1 登録情報
| フィールド | 値 |
| :--- | :--- |
| id | `NOX_EVOLVED` |
| name | `NOX: EVOLVED` |
| gameMode | `NOX_EVOLVED` |
| world | `Muldraugh, KY` |
| hourOfDay | 9 |
| xcell / ycell | 48 / 13 |
| x / y / z | 124 / 115 / 0 |

### 15.2 コールバック実装
| メソッド | 役割 |
| :--- | :--- |
| `OnInitWorld()` | SandboxVarsの上書き + `NE.InitWorldData()` |
| `AddPlayer(playerNum, playerObj)` | `NE.InitPlayerData(playerObj)` |
| `RemovePlayer(playerObj)` | ログ出力のみ |
| `Render()` | 空実装（バニラの要求を満たすため） |
| `Init()` | ログ出力のみ |

---

## 16. デバッグツール — NE_DebugTools.lua (client)
右クリックメニューに `"--- NOX: EVOLVED DEBUG ---"` サブメニューを追加。

| メニュー項目 | 効果 |
| :--- | :--- |
| SET POLLUTION: 100% (MUTATE) | `NE_Pollution = 100` |
| SET POLLUTION: 0% | `NE_Pollution = 0` |
| WARP: ENDING POINT (GOAL) | 未定（将来的に実装） |
| WARP: MEDICAL SHELTER (START) | (14524, 4015, 0) へテレポート |
| TIME SKIP: +50 DAYS (PHASE 4) | 50日スキップ、Phase4 + 審判の日フラグ設定 |
| TOGGLE: GOD MODE | `setGodMod()` の切替 |
| RESET: EVOLUTION TRIGGER | `NE_MutatedFinalTrigger = nil` |

---

## 17. 翻訳システム (i18n)
`media/lua/shared/Translate/` 配下に EN / JP の2言語を実装。

### 17.1 主要翻訳キー
| キー | 用途 |
| :--- | :--- |
| `IGUI_NE_Instinct_Title` | 本能メッセージのタイトル |
| `IGUI_NE_Instinct_1` ～ `_50` | 日数別本能テキスト |
| `IGUI_NE_Start_1` ～ `_4` | 導入シーンのセリフ |
| `IGUI_NE_Core_Access` / `_Denied` | バンカー端末メニュー |
| `IGUI_NE_Wash_Body` | 漂白剤アクション名 |
| `IGUI_NE_Evolution_*` | 進化UI関連 |
| `IGUI_NE_Debug_*` | デバッグメニュー |
| `IGUI_NE_Effect_*` | 汚染段階デバフのテキスト |
| `IGUI_NE_Notice_*` | 汚染通知テキスト |
| `Challenge_NOX_EVOLVED_*` | チャレンジ説明文 |

---

## 18. 視覚的演出 (Visual Effects)
`NE_Environment.lua` で制御。プレイヤーに現在の「外的リスク（汚染源の近さ）」と「内的リスク（身体の侵食）」を視覚的に伝える。

### 18.1 環境毒霧 (Ambient Toxic Fog)
汚染源（ホットスポット）との距離に基づく演出。画面全体を黄緑色のフィルタで覆う。
※ `CalculateViralFactor` の結果（Factor）を使用。

| 区域 | Factor | フィルタ強度 (α) | **霧の物理濃度** | 演出意図 |
| :--- | :--- | :--- | :--- | :--- |
| **Zone 1 (中心部)** | 1.0 (0%〜20%) | **0.5** | **0.8〜1.0** | 視界数メートルの濃霧。 |
| **Zone 2** | 0.8 (20%〜40%) | 0.4 | 0.6 | はっきりとした緑色の霧。 |
| **Zone 3 (中間部)** | 0.6 (40%〜60%) | 0.3 | 0.4 | 視覚的な距離感の喪失。 |
| **Zone 4** | 0.4 (60%〜80%) | 0.2 | 0.2 | 薄っすらとした靄（もや）。 |
| **Zone 5 (外縁部)** | 0.2 (80%〜100%) | 0.1 | 0.1 | 景色の違和感。 |


- **例外**: 序盤（Day 1〜5）は一律 α0.1 固定でマイルドな導入。

### 18.2 トンネルビジョン (Tunnel Vision)
プレイヤー自身の汚染度（NE_Pollution）に基づく演出。画面の端から暗い影が迫り、視野を奪う。
※ **隠密性を奪わず、脆弱性を高める** ための主デバフ。

| 汚染度 | 影の幅 (Border) | 透明度 (Alpha) | 影響 |
| :--- | :--- | :--- | :--- |
| **0% 〜 30%** | なし | 0.0 | 正常な視界。 |
| **30% 〜 60%** | 最大10%まで拡大 | 0.0 〜 0.3 | わずかに周辺視野がぼやける。 |
| **60% 〜 80%** | 最大25%まで拡大 | 0.3 〜 0.4 | 重要な情報（真横の敵）が見えにくくなる。 |
| **80% 〜 100%** | **最大35% (中心のみ)** | **0.5 (半透明な影)** | 極限の閉塞感。影越しに微かな動きは察知可能。 |


---

## 19. 季節的環境適応
世界の侵食（Erosion）スピードを月ごとに動的に調整する。ゲームは10月1日からスタートし、最初はマイルドだが後半に絶望を加速させる。

| 月 | 季節 | ErosionSpeed値 | 速度名称 | 倍率目安 |
| :--- | :--- | :--- | :--- | :--- |
| **12月** | 冬 | 3 | Slow | 0.5x |
| **1月** | 冬 | 3 | Slow | 0.5x |
| **2月** | 冬 | 3 | Slow | 0.5x |
| **3月** | 春 | 2 | Normal | 1.0x |
| **4月** | 春 | 2 | Normal | 1.0x |
| **5月** | 春 | 2 | Normal | 1.0x |
| **6月** | 夏 | 1 | Fast | 2.0x |
| **7月** | 夏 | 1 | Fast | 2.0x |
| **8月** | 夏 | 1 | Fast | 2.0x |
| **9月** | 秋 | 2 | Normal | 1.0x |
| **10月** | 秋（開始月） | 2 | Normal | 1.0x |
| **11月** | 冬 | 3 | Slow | 0.5x |

- **開始**: 10月1日。秋の標準速度からスタートし、冬に鈍化。春に復帰。夏にウィルスの侵食が最速化する。
- **ゲームプレイ上の意図**: 50日間（10月〜11月下旬）はErosion速度が低い方から始まるため、プレイヤーにとって最初は「マイルドな序盤」となるが、仮に長期生存した場合、夏季に地獄を迎える。

---

## 20. 推奨導入MOD：技術連携定義書 (Technical Integration)
本MODは単体でも動作するが、以下の強力な外部MODのアセットを前提にロジックを構成している。

```
require=Arsenal(26)GunFighter,Brita,ExpandedHelicopterEvents
```

### 20. 進捗と報酬 (Survival Progression)
詳細は [9.1 節](#9.1-進化の瞬間：日数別ポイント配布とデトックス) を参照。
生存日数に応じたマイルストーンで、進化ポイント(EP)と汚染度の自浄作用（デトックス）を獲得できる。

- **実名ID定義**:
  - 除菌放射器: `Base.M2A1` (M2A1 Flame Thrower), `Base.WD_Flame` (WD-40型代用品)
  - 燃料/マガジン: `Base.M2A1_Can`, `Base.M2A1_Tank`, `Base.FlameFuel`
- **指示**: アイテムID `Base.M2A1` の `OnAttack` 関数をあなたのMODでフックし、浄化ロジックを割り込ませなさい。
- **指示**: **[API制約回避: Erosionリセット]**: バニラのErosionシステムはピンポイントな除去が困難であるため、既存MODの関数を直接上書きするのではなく、安全なイベントフック（対象タイルの取得）を用いて、射程内にある上述のカスタム蔓オブジェクト（`IsoObject`）を検索し、`square:RemoveTileObject()` で削除する独立したスクリプトを構築しなさい（延焼判定も `false` 化）。
- **指示**: 燃料レシピを上書きし、漂白剤を用いた `Refill M2A1 Tank` レシピを `NE_BleachActions.lua` で再定義しなさい。

### 20.2 [Expanded Helicopter Events]
- **役割**: 50日目の「審判の爆撃」および「地上浄化部隊（NPC）」の襲来。
- **実名プリセットID**:
  - `air_raid`: サイレン演出と広域警告音。
  - `jet_bombing`: 絨毯爆撃（Carpet Bomb）演出。
  - `military_attack_all`: 対生存者・ゾンビ無差別攻撃。
- **指示**: `eHelicopter_PRESETS["jet_bombing"]` の `addedFunctionsToEvents["OnLaunch"]` をフックし、着弾時のエフェクトを「爆発」から「落雷＋広域火災」のスクリプトへ差し替えなさい。
- **指示**: エンディング2（共生）を選んだ際、このMODの `military_attack_all` スケジュールを `On24Hours` で強制起動させ、軍がプレイヤーを「最優先排除対象」として追跡するフラグを立てなさい。

### 20.3 [Shark and Peach's Military Uniforms]
- **役割**: 「エリート」や「地上部隊」に外見を与える衣装ライブラリ。
- **指示**: エリートゾンビ（White Elite）がスポーンする際、`Inventory:AddItem` で特定モデルを強制装着させなさい。
- **指示**: 防護服の「汚染抵抗値」をあなたのMODの `PollutionRate` と計算式で結合し、装備の劣化に合わせて汚染スピードが変わるロジックを組み込む。

### 20.4 [Cryogenic Winter / Toxic Fog]
- **役割**: 50日間で霧の色や濃度が段階的に悪化していく視覚演出。
- **指示**: `ClimateManager` を操作して、霧の色を生存日数に応じて動的にシフトさせなさい。既存の「外にいるだけでダメージを受ける」ロジックを、あなたの累積汚染度の計算式に置き換えなさい。

### 20.5 外部MOD一覧
| MOD名 | 役割 |
| :--- | :--- |
| **Arsenal(26) Gunfighter Mod [2.0]** | 銃器の発砲音とマズルフラッシュの制御 |
| **Brita's Weapon Pack** | 汚染区域のエリートゾンビが所持する特殊兵装のアセット供給 |
| **Expanded Helicopter Events** | 50日目の空爆演出（AirStrike）および軍 shop のパトロールヘリ |

---

## 21. イベント登録一覧（全モジュール）

| イベント | 登録関数 | ファイル |
| :--- | :--- | :--- |
| `Events.OnCreatePlayer` | `NE_OnCreatePlayer` | NE_StartScene.lua |
| `Events.OnCreatePlayer` | `OnCreatePlayer` | NE_PlayerManager.lua |
| `Events.OnPlayerUpdate` | `NE_StartSceneTick` | NE_StartScene.lua (動的追加/解除) |
| `Events.OnPlayerUpdate` | `OnPlayerUpdate` | NE_PlayerManager.lua |
| `Events.OnTick` | `NE_UpdateEnvironment` | NE_Environment.lua |
| `Events.OnTick` | `NE_UpdateViralStressHUD` | NE_ViralStressHUD.lua |
| `Events.OnGameOver` | `NE_OnEndGame` | NE_Environment.lua |
| `Events.OnGameStart` | `NE_ShowInstinct` | NE_LoreManager.lua |
| `Events.EveryHours` | `NE_CheckDailyLore` | NE_LoreManager.lua |
| `Events.EveryOneMinute` | `NE_CheckMutationState` | NE_LoreManager.lua |
| `Events.EveryOneMinute` | `NE_ApplyPollutionEffects` | NE_PollutionEffects.lua |
| `Events.EveryOneMinute` | `NE_EndGameTick` | NE_EndGame.lua |
| `Events.EveryTenMinutes` | `OnUpdatePollution` | NE_PlayerManager.lua |
| `Events.EveryTenMinutes` | `NE_PollutionNotification` | NE_PollutionEffects.lua |
| `Events.EveryDays` | `OnUpdateWorld` | NE_WorldManager.lua |
| `Events.OnInitWorld` | `OnInitWorld` | NE_WorldManager.lua |
| `Events.OnInitWorld` | `NE_ForceSandboxOptions` | NE_SandboxDefaults.lua |
| `Events.OnWeaponSwing` | `NE_OnWeaponSwing` | NE_SanitizerLogic.lua |
| `Events.OnZombieUpdate` | `(anonymous)` | NE_MutantManager.lua |
| `Events.OnZombieDead` | `NE_OnZombieDead` | NE_MutantManager.lua |
| `Events.OnFillInventoryObjectContextMenu` | `NE_BleachMenu` | NE_BleachActions.lua |
| `Events.OnFillWorldObjectContextMenu` | `NE_OnDebugMenu` | NE_DebugTools.lua |
| `Events.OnFillWorldObjectContextMenu` | `NE_OnFillWorldObjectContextMenu` | NE_EndGame.lua |
| `Events.OnChallengeQuery` | `NOX_EVOLVED_CHAL.Add` | Challenge_NOX_EVOLVED.lua |

---

## 22. ModData キー一覧

### ワールド (`GameTime:getModData()`)
| キー | 型 | 概要 |
| :--- | :--- | :--- |
| `NE_SurvivalDays` | number | 経過日数 |
| `NE_WorldPhase` | number | 現在フェーズ (1-4) |
| `NE_DynamicHotspots` | table | 動的汚染源の座標リスト |
| `NE_JudgementDayArrival` | boolean | 50日目イベント開始フラグ |
| `NE_PhaseShiftTrigger` | boolean | フェーズ遷移演出フラグ |

### プレイヤー (`player:getModData()`)
| キー | 型 | 概要 |
| :--- | :--- | :--- |
| `NE_Initialized_V2` | boolean | V2用初期化完了フラグ |
| `NE_Pollution` | number | 蓄積汚染度 (0-100) |
| `NE_StartSequence` | number | 導入演出の進行段階 |
| `NE_StartTimer` | number | 導入演出のティックタイマー |
| `NE_StartSceneInit` | boolean | StartScene初期化完了 |
| `NE_StartSceneFinished` | boolean | 導入シーン完了フラグ |
| `NE_MutatedFinalTrigger` | boolean | 100%汚染による進化済みフラグ |
| `NE_TriggerEndingUI` | boolean | エンディングUI表示フラグ |

### ゾンビ (`zombie:getModData()`)
| キー | 型 | 概要 |
| :--- | :--- | :--- |
| `NE_MutantChecked` | boolean | 変異判定済み |
| `NE_MutantType` | string | `"Scout"` / `"Elite"` / `"Reinfected"` |
| `NE_EliteTimer` | number | エリートの咆哮カウンター |
| `NE_HasFireProof` | boolean | 耐火フラグ |
| `NE_UpdateTicks` | number | 更新ティックカウンター(負荷分散) |

---

## 23. 未実装・設計段階の仕様
以下はDOC.mdに設計として記載があるが、現時点のコードベースには**未実装**の仕様。

1. **空爆のプレイヤー建築物ターゲティング** (壁・ゲート密度優先爆撃) — 現在はランダム座標のみ。
2. **除菌剤の恒久的HP減少** — 現在は単発の15HPダメージのみ。
3. **Expanded Helicopter Events との直接連携** (AirStrike差替、MilitaryHunterスケジュール) — 自前の爆撃ロジックで代替中。
4. **Shark and Peach's Military Uniforms 連携** — 基本的な `Hat_Army` / `Vest_BulletArmy` のみ。
5. **Build 42 対応計画** (地下システム、新照明エンジン) — 将来の計画。

---

## 24. Build 42 実装と高度な統合 (Current)
- **地下・高低差**: ルイビル病院の地下階層および屋上ヘリポートを活用した、B42の拡張された垂直空間でのイベント。
- **家畜変異**: B42で追加された家畜（牛・羊等）へのウィルス感染・変貌ロジックの統合。
- **流体システム**: B42の新しい液体（Fluid）管理を用いた、より精密な「ウイルス汚染血液」の汚染痕跡（スプラッター）の追跡と洗浄。
- **音響エンジン**: B42の新しい音響システムを活かし、地下施設内の残響や警告アナウンスの没入感向上。
- **照明エンジン**: B42の新照明を活かし、地下施設内の「非常灯（赤色）」演出を統合。

---

> [!NOTE]
> **End of Document**
> コードの変更を行った場合は、本ドキュメントも同時に更新してください。
