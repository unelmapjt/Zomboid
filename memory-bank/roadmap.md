# Roadmap State — NOX: EVOLVED (B42)

> 本ファイルは `Docs/Specifications/ROADMAP.md` の**現在の進捗状態**を memory-bank 視点で記録する。
> 詳細な実装仕様は `Docs/Specifications/ROADMAP.md` を、設計の意図は `MDD` を参照せよ。

---

## 現在のフェーズ

**フェーズ**: Phase 1 — プロローグ・基盤実装

---

## 完了済み（✅）

- [x] チャレンジ定義 (`NE_HyperErosion.lua`)
- [x] 初期スポーン・テレポート (`NE_StartScene.lua`)
- [x] 初期装備セットアップ（病院着・ガスマスク・ハザマット）
- [x] Dr.Hiro 遺体生成（`IsoDeadBody.new` 方式）
- [x] プロローグ喉負傷
- [x] プロローグダイアログ（5 ページ）
- [x] Z_TRACER ロギング統合
- [x] カメラズーム演出の廃止（安定化）

---

## 進行中（🔄）

- [ ] プロジェクト統治アーキテクチャの再設計（実施中）

---

## 次の優先事項（📌）

- [ ] HUD 実装（`NE_ViralStressHUD.lua`）— 変異度・ウイルスストレス表示
- [ ] 汚染ロジック実装（`NE_Core.lua` §4.1〜）
- [ ] NE_LoreManager.lua の完成
