# Z System Logging Specification

このドキュメントは、`Z_Core.lua` と `Z_Tracer.lua` の現在実装に基づく `Z_LOG` / `Z_TRACE` の正式仕様である。  
将来の実装・修正・Cursorへの指示は、必ず本仕様に一致させること。

## 1) Z_LOG (`Z_Core.lua`)

### 1.1 目的
- エラー/診断情報を JSON 1行ログとして安定出力し、`Console.txt` から機械抽出しやすくする。

### 1.2 出力構造（キー順を含めて固定）
- 文字列テンプレート（実装準拠）:

```text
{"Z_LOG":true,"id":"ERR_...","file":"...","line":...,"msg":"...","ctx":"..."}
```

- フィールド定義:
  - `Z_LOG`: 常に `true`
  - `id`: エラー識別子（`ERR_<file>_<line>_<msgPart>`）
  - `file`: 発生元ファイル（`debug.getinfo` 由来）
  - `line`: 発生行番号（数値）
  - `msg`: メッセージ本文
  - `ctx`: 補足コンテキスト（未指定時 `"none"`）

### 1.3 `id` 生成仕様（最新実装）
- **形式**: `ERR_<fileName>_<line>_<infoTag>_<msgPart>`
- **fileName**: `short_src` の末尾ファイル名（`/` と `\` の両対応）
- **line**: エラー発生行
- **infoTag**: 
  - 呼び出し元の関数名、または種別（`info.name` / `info.namewhat`）の先頭6文字
  - 検出不能な場合は `"NA"`
- **msgPart**:
  - メッセージから空白と記号（`[^%w]`）を除去した先頭5文字
  - **日本語等の非ASCII文字のみで上記が空になる場合**: `msg` の最初の4バイトを **16進数文字列** に変換して採用（例: `E381...`）
  - それでも空、あるいは変換不能な場合は `"X"`

### 1.4 文字保護（`escapeJson`）
- `Z_LOG` 文字列組み立て前に `id` / `file` / `msg` / `ctx` へ適用すること。
- 変換ルール:
  - `\` -> `\\`
  - `"` -> `\"`
  - `\t` -> `\\t`
  - 改行（`\r\n`, `\n`, `\r`）-> `\\n`

## 2) Z_TRACE (`Z_Tracer.lua`)

### 2.1 目的
- 実行フロー（イベント開始/終了、クラッシュ、ネットワーク境界）を時系列追跡可能にする。

### 2.2 出力構造（キー順を含めて固定）
- 文字列テンプレート（実装準拠）:

```text
{"Z_TRACE":true, "level":"...", "type":"...", "target":"...", "action":"..."}
```

- フィールド定義:
  - `Z_TRACE`: 常に `true`
  - `level`: `DEBUG` / `INFO` / `WARN` / `ERROR`
  - `type`: トレース種別（例: `EVENT`, `NET_SEND`, `FATAL`）
  - `target`: 対象名（例: `OnGameStart`, `Module:Command`）
  - `action`: 動作（例: `START`, `END`, `C2S`, `S2C`, `CRASH: ...`）

### 2.3 出力制御（Config）
- `Z_TRACER.Config.TRACE_ENABLED`（既定: `true`）
  - `false` の場合、`Z_TRACE` は一切 `print` しない。
- `Z_TRACER.Config.TRACE_LEVEL`（既定: `"INFO"`）
  - 閾値方式でフィルタする。
  - 優先順位: `DEBUG < INFO < WARN < ERROR`
  - `msgPriority < currentPriority` の場合は出力しない。

### 2.4 レベル決定仕様
- 基本: `msgLevel = optionalLevel or getTraceLevel(traceType, action)`
- `optionalLevel` が指定された場合はそれを優先（大文字化して評価）
- 未指定時の `getTraceLevel`:
  - `traceType == "FATAL"` -> `ERROR`
  - `action == "START"` または `action == "END"` -> `DEBUG`
  - それ以外 -> `INFO`

## 3) 実装/運用ルール

### 3.1 ログ出力の禁止事項
- 生の `print()` で独自ログを出力してはならない。
- ログ出力は必ず `Z_Core` または `Z_Tracer` の経路を使用すること。
  - エラー/診断: `Z_CORE.Log(...)` / `Z_CORE.Err(...)`
  - トレース: `emitTrace(...)` を通る既存ラッパー経路

### 3.2 B42 / MP / 互換性要件
- `WrapCallback` の戻り値展開は `unpackFn`（`rawget(table, "unpack") or unpack`）を使用し、Lua 5.1 / 5.2+ 差異を吸収すること。
- これにより、イベントコールバックの可変長戻り値を欠落させず、既存挙動を維持する。

### 3.3 ホットリロード安全性
- イベント `Add` の再ラップ防止に `eventObj.__z_wrapped` を使用する。
- グローバル送信関数の再ラップ防止に `_G.__z_sendClientCommand_wrapped` / `_G.__z_sendServerCommand_wrapped` を使用する。
- ホットリロード時でも二重ラップでログが重複しないことを維持する。

## 4) Cursor向け指示テンプレート（厳守）

- `Z_LOG` を生成/変更する際は、次の形を維持すること:

```text
{"Z_LOG":true,"id":"%s","file":"%s","line":%d,"msg":"%s","ctx":"%s"}
```

- `Z_TRACE` を生成/変更する際は、次の形を維持すること:

```text
{"Z_TRACE":true, "level":"%s", "type":"%s", "target":"%s", "action":"%s"}
```

- キー名、キー順、`true` の表記、区切り記号、空白位置を変更しないこと。
