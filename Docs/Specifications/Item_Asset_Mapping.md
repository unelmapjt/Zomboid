# NOX: EVOLVED - Item Asset Mapping

このドキュメントは、MOD独自のアイテムをバニラの資産（アイコン、3Dモデル、SE）を流用して実装するための対応表である。

## 1. 医療・薬品 (Medical Items)

| アイテム名 | 翻訳キー (ItemName.json) | 流用元アイコン | 特徴・連動演出 |
| :--- | :--- | :--- | :--- |
| **抗変異薬** | `DisplayName_NE_AntiMutantDrug` | `Vitamins` | アイコンを「青色/水色」に指定。服用時に心音SEを再生。 |
| **汚染遅延剤** | `DisplayName_NE_Retardant` | `BetaBlockers` | 黄色い錠剤。服用後30分間、HUDにシールドアイコンを表示。 |
| **NE-セラム** | `DisplayName_NE_Serum` | `Inhaler` / `Syringe` | 特殊な容器。進化した瞬間に画面フラッシュ。 |

## 2. 防護装備 (Protective Gear)

| アイテム名 | 翻訳キー (ItemName.json) | 流用元 3Dモデル | 独自システム |
| :--- | :--- | :--- | :--- |
| **プロトタイプ・ガスマスク** | `DisplayName_NE_GasMask` | `GasMask` | `NE_FilterLife` による耐久消費。 |
| **試作型防護服** | `DisplayName_NE_HazmatSuit` | `HazmatSuit` | 全身パーツ。通常の衣類より高い切断・汚染耐性。 |
| **交換用フィルター** | `DisplayName_NE_FilterReload` | `Battery` / `DuctTape` | 消耗品。ガスマスクを右クリックで「交換」に使用。 |

## 3. 除菌・浄化ツール (Sanitization Tools)

| アイテム名 | 翻訳キー (ItemName.json) | 流用元モデル/エフェクト | 動作メカニズム |
| :--- | :--- | :--- | :--- |
| **除菌噴霧器** | `DisplayName_NE_DeconSpray` | `Extinguisher` | 消火器の噴射パーティクルを流用。床のToxicityを消去。 |
| **除菌手榴弾** | `DisplayName_NE_DeconGrenade` | `Smoke Bomb` | 発煙弾をベースに、煙の範囲内のToxicityを中和。 |
| **自家製除菌液** | `DisplayName_NE_HomemadeSanitizer` | `Bleach` (リカラー) | 漂白剤のアイコンを「茶色/透明」にして作成。 |

## 4. クエスト・重要アイテム (Quest Items)

| アイテム名 | 翻訳キー (ItemName.json) | 流用元アイコン | 役割 |
| :--- | :--- | :--- | :--- |
| **軍事研究所アクセスキー** | `DisplayName_NOX_EVO_B42_B17_AccessKey` | `KeyID` | B17施設の扉を解錠するための物理的なカードキー。Dr.ヒロが所持。 |
| **ノックス病変異核 (Alpha～Delta)**| `DisplayName_NOX_EVO_B42_NE_Nucleus_Alpha` 等 | `Vial` (リカラー) | 各地の震源地に残されたウィルス核。赤/青/緑/黄。 |
| **機密書類「NOX:EVOLVED Report」**| `DisplayName_NOX_EVO_B42_NE_SecretReport` | `SheetMusic` / `Journal` | 右クリック「読む」で専用UI（7.1節）を表示。 |
| **機密アタッシュケース** | `DisplayName_NOX_EVO_B42_NE_ConfidentialBriefcase` | `Suitcase` | 各地の最深部に配置されるコンテナ。変異核と重要物資を保護している。 |

## 5. スクリプト実装時の注意点 (Technical Notes)

*   **Color 変数**: 多くのアイテムは、スクリプト内の `ColorRed`, `ColorGreen`, `ColorBlue` を指定するだけで既存アセットの色を変更できる。
*   **DisplayName**: 翻訳ファイルを直接参照するよう、Lua側では `DisplayName` を定義せずに翻訳キーを使用する。
*   **Weight (重さ)**: 
    *   抗変異薬: 0.1
    *   ガスマスク: 1.5 (フィルター込み)
    *   防護服: 5.0
    *   変異核: 0.5 (液体を含むため少し重め)
    *   アクセスキー: 0.01 (無視できる重さ)
