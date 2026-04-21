# Item Registry — NOX: EVOLVED (B42)

> B42 で実在が確認されたアイテム ID の一覧。
> 確認ソース: `generated/items/` または `Docs/Decomp/`
> 記載のないアイテムは使用前に必ず `generated/` を grep で確認すること。

---

## 確認済みアイテム

| アイテムID | カテゴリ | 確認先ファイル | 存在 |
|-----------|---------|--------------|------|
| `Base.JacketLong_Doctor` | 衣類 | `generated/items/clothing.txt` | ✅ 存在 |
| `Base.Shoes_Slippers` | 衣類 | `generated/items/clothing.txt` | ✅ 存在 |
| `Base.HospitalGown` | 衣類 | `generated/items/clothing.txt` | ✅ 存在 |
| `Base.Hat_GasMask` | 衣類 | `generated/items/clothing.txt` | ✅ 存在（`Base.GasMask` は不正解）|
| `Base.HazmatSuit` | 衣類 | `generated/items/clothing.txt` | ✅ 存在 |
| `Base.FirstAidKit` | コンテナ | `generated/items/container.txt` | ✅ 存在 |
| `Bag_Satchel_Medical` | 衣類 | clothing.txt / container.txt | ❌ B42に存在しない |

---

## B42 スクリプトファイルの場所

- **B41（旧）**: `media/scripts/items.txt` 等に直接記述
- **B42（新）**: `media/scripts/generated/` 以下に自動生成されているものが多い
- バニラのアイテム定義を探す場合、まず `generated/` サブフォルダを確認すること

---

## ✏️ 更新ルール

- 動作確認済みのアイテム ID のみ追記する
- 存在しないことが確認されたアイテムは ❌ として明記する（削除しない）
