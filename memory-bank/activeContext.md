# Active Context: NOX_EVO_B42

## 1. 現在のプロジェクト状況
- 開発の基盤となるデバッグOS「Z-System (Z_Core.lua, Z_Tracer.lua, .cursorrules)」のデプロイが完了。
- ワークスペースのインデックス汚染を防ぐため `.cursorignore` を設定済み。
- 過去の冗長なデバッグスクリプトやファイル分割構想を破棄し、実務最小構成へ移行した状態。
- `Z_Core.lua` の JSON ログ出力にエスケープ処理（`\`, `"`, 改行, タブ）を追加し、ログ破損耐性を改善。
- `Z_Tracer.lua` の可変長戻り値展開を `unpackFn = table.unpack or unpack` に統一し、Lua 5.1/5.2+ 互換性を明示化。
- `Z_Tracer.lua` の `sendClientCommand` ラッパーを PZ クライアント仕様 `(module, command, args)` に修正し、C2S 呼び出し引数の整合性を回復。
- `Z_Tracer.lua` に `Config.TRACE_ENABLED` / `Config.TRACE_LEVEL` を導入し、`DEBUG < INFO < WARN < ERROR` に基づく出力フィルタを追加。
- `emitTrace` に第4引数 `optionalLevel` を追加し、必要時に明示レベル指定できる拡張ポイントを実装（未指定時は既存の `getTraceLevel` を維持）。
- `Z_Tracer.lua` のホットリロード対策として、`eventObj.__z_wrapped` と `_G.__z_*_wrapped` ガードを追加し、イベント/送信関数ラップの二重適用を防止。
- `Z_Core.lua` の `getErrorID` を拡張し、`ERR_<file>_<line>_<msgPart>` 形式でメッセージ由来識別子（英数字5文字）を付与して同一行内識別を改善。
- `Z-Copy.bat` と `Get-ZLog.ps1` に失敗時ハンドリングを追加し、抽出/コピー失敗時に非0終了コードを返して `.bat` 側でエラー表示＋`pause` する運用に改善。
- `Docs/Specifications/Z_System_Logging.md` を新規作成し、`Z_LOG` / `Z_TRACE` の出力フォーマット・キー順・制御仕様・運用ルール（print禁止、unpackFn保証）を固定化。
- `Z_Core.lua` の `getErrorID` を再強化し、非ASCIIメッセージ時は先頭バイト16進（`toHexPrefix`）へフォールバックし、`info.name/namewhat` 由来タグもIDへ合成して同一行衝突をさらに低減。

## 2. 重要な技術的前提
- Build 42 の Lua 環境で動作することが最優先。
- **Z-System駆動開発**: 全ての実装とデバッグは、`Console.txt` に出力される `Z_LOG` と `Z_TRACE` に基づく「最小差分（Minimal Diff）」の適用によって進行する。
- 50日目のエンドゲームシステムを軸に、汚染と進化のフェーズ設計を実装する（要件自体は維持）。

## 3. 次の作業優先度
1. 実装の第一歩として、基盤となる `NE_Core.lua`（汚染係数計算・定数管理・グローバル初期化）の最小構成をCursorに指示し、実装させる。
2. 実装後、Zomboidを起動して挙動を確認する。
3. エラーまたは想定外の挙動があれば、`Console.txt` の `Z_LOG` / `Z_TRACE` を抽出してCursorに投げ、修正ループを確立する。
4. 基盤が安定した後に、UI（`NE_ViralStressHUD.lua`）やゾンビ変異（`NE_MutantManager.lua`）へ段階的に拡張する。

## 4. リスクと注意点
- 1回のプロンプトで複数の機能実装を要求しない（Semantic Overloadの回避）。
- Cursorにアーキテクチャの設計判断を委ねない。あくまで「指示された仕様のコード化」と「ログに基づくパッチ生成」に特化させる。