# Build 42 確定採用 MOD リスト (Implementation Standard)

Build 42 環境で動作が確認されている、または B42 ネイティブ設計の推奨 MOD リストです。

## 1. 必須インフラ (Core Infrastructure)
| MOD 名 | **Workshop ID** | **Mod ID** | 役割 / 依存関係 |
| :--- | :--- | :--- | :--- |
| **B42 ModOptions** | **3386860561** | `B42ModOptions` | **必須**。B42 本体の設定システム。 |
| **Error Magnifier** | **2896041179** | `errorMagnifier` | 必須。詳細なデバッグログ出力。 |
| **Mod Update and Alert System** | **3077900375** | `chuckleberryModdingAlertSystem` | 必須。ErrorMagnifier の前提。 |
| **HEF - Helicopter Event Framework** | **3672792485** | `HEF` | **必須**。B42 専用イベント基盤（空爆・毒ガス）。 |

## 2. 推奨機能拡張 (Recommended Extensions)
| MOD 名 | **Workshop ID** | **Mod ID** | 役割 |
| :--- | :--- | :--- | :--- |
| **Random Zombies** | **2818577583** | `BLTRandomZombies` | 変異体出現率の B42 制御。 |
| **Armored Vests Patch** | **1962761540** | `ArmoredVests` | 装備性能強化。 |
| **[B42] Mod Manager** | **3567084868** | `ModManager` | B42 用モッド管理ツール。 |

---
**本プロジェクトの方針**:
大型の B41 MOD re-upload（EHE, Brita 等）への依存を排除し、**B42 バニラのアセット（Chemical Sprayer, Aerosol Bomb 等）および HEF などの新世代 B42 フレームワーク** を中心に構築します。
