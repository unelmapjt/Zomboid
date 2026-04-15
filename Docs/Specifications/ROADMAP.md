# ROADMAP: NOX_EVO_B42 (Z-System Driven)

> [!IMPORTANT]
> 本ロードマップは `Master Design Document.md` の現行仕様に同期し、`Z_Core.lua` / `Z_Tracer.lua` を用いた決定論的開発ループを前提とする。

---

## Phase 0: Foundation Reset
- [ ] ワークスペースとディレクトリ標準の固定
- [ ] `mod.info` / 依存定義 / バージョン整合
- [ ] Z-System トレースキー命名規約の確定

## Phase 1: Core Pollution Engine
- [ ] `NE_Core` 定数と汚染係数計算の確定
- [ ] 3D距離・垂直減衰・キャッシュ戦略の固定
- [ ] 汚染ホットスポット拡大ロジックの検証

## Phase 2: Viral Stress Runtime
- [ ] `NE_PlayerManager` の10分更新ループ整備
- [ ] 段階別デバフの適用順序確定
- [ ] Barking通知とHUD同期の検証

## Phase 3: B42 Fluid Integration
- [ ] 汚染血液Fluid生成フローの実装
- [ ] Fluid濃度と汚染増分の連携
- [ ] 洗浄時のFluid減衰アルゴリズムの確定

## Phase 4: B42 Animal Infection
- [ ] 動物感染ステートマシン実装
- [ ] 汚染接触イベントの抽象化
- [ ] 変異動物の挙動・討伐時汚染の検証

## Phase 5: Start Sequence & Narrative
- [ ] 導入シーケンスと初期配布の確定
- [ ] Dr.Hiro導線とカードキー回収体験の固定
- [ ] 本能メッセージの翻訳キー同期

## Phase 6: Decontamination Systems
- [ ] 漂白剤アクション2種の調整
- [ ] Chemical Sprayer / Aerosol系浄化ループ整備
- [ ] 浄化と副作用のバランス固定

## Phase 7: Mutant Ecosystem
- [ ] Scout / Elite / Reinfected の確率設計
- [ ] 変異体負荷対策（更新間引き）確定
- [ ] ゾンビ・動物混在シーンの安定化

## Phase 8: World Phase & Endgame Pressure
- [ ] Day 50審判フェーズ遷移確定
- [ ] HEF + バニラ連携イベントの検証
- [ ] 地下17階攻略導線の最適化

## Phase 9: Endings & Persistence
- [ ] 3エンディング分岐条件の固定
- [ ] 終了時ログと状態保存の整備
- [ ] 継続プレイ時の後日談パラメータ定義

## Phase X: Hardening Loop (Z-System)
- [ ] トレース駆動の回帰テスト運用
- [ ] 重大不具合の最小修正プロトコル適用
- [ ] ドキュメント/実装/ログの完全同期監査
