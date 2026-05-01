# Step 0 ホワイトリスト（B42 正規構文）

- アイテムの主型は **`ItemType = base:...`**（`base:normal` / `base:literature` / `base:drainable` / `base:clothing` / `base:weapon` 等）を用いる。
- レガシー **`Type = Normal` 等の B41 構文は使用しない**（`ItemType` に統一）。

## Step 1 B42 NPC/インベントリ制御

- **性別固定**: `setFemale(bool)` と **`setIsFemale(bool)`** を併用して Descriptor を初期化する。
- **インベントリ清掃**: 名前付き NPC の `Base.IDCard` 重複を避けるため、`inv:clear()` 後に `inv:RemoveItem("Base.IDCard")` でバニラ配布品を明示的に除去する。
