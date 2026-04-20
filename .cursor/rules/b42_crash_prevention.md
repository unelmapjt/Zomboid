# B42 開発における再発防止策 (Crash Prevention Rules)

## 2.4.1 Challenge / Last Stand の実体化

`addChallenge()` で登録するテーブルには **`Init`**、**`Render`**、**`AddPlayer`** コールバックを必ず定義する（空でも可）。これはバニラの `LastStandSetup.lua` がこれらを無条件に呼び出すためである。

## 2.4.2 SandboxVars の安全な参照

- 常に `if not SandboxVars then return end` を先頭に置くこと。
- サブテーブルはエイリアスを考慮して `SandboxVars.NOX_EVO_B42 or SandboxVars.NOX_EVOLVED or SandboxVars.NOX_EVO` の形式で取得し、`nil` チェック後にメンバへアクセスすること。

## 2.4.3 ブラックリスト (Negative Context) の遵守

- **必須参照**: 新規の実装、特にカメラ、視覚エフェクト、エンティティ生成を行う際は、必ず `memory-bank/negative-context.md` を確認し、禁止されているパターンを踏んでいないかチェックすること。
- **失敗の記録**: Java 例外やクラッシュを引き起こした API は、解決後直ちに同ファイルへ追記し、再発を防止すること。
