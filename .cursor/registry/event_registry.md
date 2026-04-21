# Event Registry — NOX: EVOLVED (B42)

> B42 で使用が確認されたイベント名の一覧。
> 確認ソース: `Docs/Decomp/` または バニラ Lua 参照

---

## 確認済みイベント

| イベント名 | 発火タイミング | 引数 | 備考 |
|-----------|-------------|------|------|
| `Events.OnCreatePlayer` | プレイヤー生成時（ロード時も発火） | `(playerIndex, player)` | ロード時にも発火するため二重実行ガード必須 |
| `Events.OnTick` | 毎フレーム | なし | 高頻度。重い処理は間引くこと |
| `Events.OnPlayerUpdate` | プレイヤー更新毎 | `(player)` | カメラ制御・状態更新の推奨フック |
| `Events.OnPlayerWake` | 睡眠から覚醒時 | `(player)` | リマインド系の発火に使用 |
| `Events.OnMouseWheel` | マウスホイール操作 | - | `return true` で入力を遮断できる |
| `Events.OnPostRender` | 描画後 | なし | UI描画の後処理に使用 |

---

## ✏️ 更新ルール

- 実際に使用・確認されたイベントのみ追記する
- 引数の型や数が不明な場合は Decomp で確認してから記載する
