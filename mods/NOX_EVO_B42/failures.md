# Step -1 ブラックリスト（失敗パターン）

- **死体（コープス）インベントリに `CantBeDropped = TRUE` を付与する**  
  - Pruning / 自動削除やインベントリ不整合の原因になり得るため **使用禁止**。
- **Java オブジェクト（SurvivorDesc, ItemContainer 等）への `rawget` 使用**
  - Kahlua 内部で `ClassCastException` が発生しクラッシュするため **厳禁**。
  - **対策**: `if object.methodName then ... end` でメソッドの有無を確認すること。
