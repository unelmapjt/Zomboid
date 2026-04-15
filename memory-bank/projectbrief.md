# NOX_EVO_B42 Project Brief

## 1. プロジェクト名
NOX: EVOLVED (Build 42 Master Edition)

## 2. コンセプトと目的
- Project Zomboid Build 42 における、汚染・進化・終末をテーマとしたハードコアサバイバルMOD。
- `NE` 名前空間を中心とした汚染管理システムと「バイオ汚染」「毒霧」「進化個体」の実装。
- 50日目に向けた緊張感とストーリーを強化し、エンドゲーム演出を最終目的とする。

## 3. 対象範囲と成果物（予定）
- `media/lua/` 配下にClient/Server/Shared構造でモジュールを配置。
- **必須インフラ**: `Z_Core.lua`, `Z_Tracer.lua`
- **主要モジュール群** (順次実装):
  - `NE_Core.lua`: コアロジック
  - `NE_PlayerManager.lua`, `NE_WorldManager.lua`: 状態管理
  - `NE_MutantManager.lua`: 変異制御
  - `NE_ViralStressHUD.lua`, `NE_Environment.lua`: UIと環境
  - `NE_StartScene.lua`, `NE_EndGame.lua`: 演出

## 4. 開発指針 (Z-System Rules)
- **1機能・1プロンプト**: 一度に複数の要求を出さず、機能を最小単位に分割して実装させる。
- **設計は人間、コーディングはAI**: 構造や仕様は人間が指定し、AIにはそれをLuaコードに翻訳させる作業に特化させる。
- **推測の排除**: AIに存在しないAPIを推測させない。不明な場合はZ_Tracerのログ、またはJAVA_Docsを参照させる。