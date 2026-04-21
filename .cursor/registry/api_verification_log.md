# API Verification Log — NOX: EVOLVED (B42)

> 本ファイルは、API・挙動の**検証経緯と根拠**を記録する。
> 「なぜ確認済みと言えるか」のトレーサビリティを保持する。
> API 定義の一覧は `api_whitelist.md` を参照せよ。

---

## 検証ログフォーマット

```
### [YYYY-MM-DD] API名 / パターン名
- 検証方法: Decomp / EXT_Mod / 実機テスト
- 証拠ソース: ファイルパス or 説明
- 結果: 成功 / 失敗
- 備考: 特記事項
```

---

## 検証済みログ

### [2026-04-15] ItemContainer.AddItem / addItem / clear
- 検証方法: Decomp + 実機テスト
- 証拠ソース: `Docs/JAVA_Docs/zombie/inventory/ItemContainer.html`
- 結果: 成功
- 備考: `AddItem` (大文字A) と `addItem` (小文字a) は別オーバーロード。混同注意。

### [2026-04-15] IsoGameCharacter.setWornItem
- 検証方法: Decomp + 実機テスト
- 証拠ソース: `Docs/JAVA_Docs/zombie/characters/IsoGameCharacter.html` L385
- 結果: 成功
- 備考: 第1引数は `ItemBodyLocation` オブジェクト必須。String を渡すと ClassCastException。

### [2026-04-15] SurvivorDesc.setForename / setSurname
- 検証方法: Decomp
- 証拠ソース: `Docs/JAVA_Docs/zombie/characters/SurvivorDesc.html` L111, L117
- 結果: 成功
- 備考: `getDescriptor()` 経由で取得後に使用。

### [2026-04-15] IsoDeadBody.new(IsoGameCharacter, boolean)
- 検証方法: Decomp + バニラコード参照
- 証拠ソース: `Tutorial/Steps.lua:1096`
- 結果: 成功
- 備考: 座標を持つZombieを先に生成し、変換する方式が正しい。`new(getCell())` は NPE クラッシュ。

### [2026-04-20] IsoCamera.setZoom / cameras[0].zoom 直接代入
- 検証方法: 実機テスト（複数アプローチ）
- 証拠ソース: B42 実機エラーログ
- 結果: 失敗（Rule-G9 適用）
- 備考: `memory-bank/failures.md` に記録。B42 はカメラを Continuous Solver として扱うため、スクリプト層からの直接制御は不可能と判定。
