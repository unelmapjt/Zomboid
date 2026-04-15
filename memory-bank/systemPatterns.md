# System Patterns: NOX_EVO_B42

## 1. アーキテクチャ概要
- Client/Server/Shared の厳格な三層構造。
- `NE` 名前空間の共通化: 全モジュールが `NE.<module>` 形式でアクセス可能。
- **デバッグ層 (Z-System)**:
  - ゲームのロジックとは独立して `Z_Core.lua` と `Z_Tracer.lua` が稼働し、実行時文脈をJSONLとして監視・出力する。

## 2. 高レベル設計パターン
- **イベント駆動型更新**: `Events.EveryOneMinute` / `Events.EveryTenMinutes` などを利用し、負荷を分散。
- **モジュール分割**: UI（Client）、計算・状態（Shared）、世界・ゾンビ制御（Server）の責務分離。
- **キャッシュ戦略**: 負荷の高い汚染度計算などは座標と日時で結果をキャッシュし、再計算をスキップする。

## 3. Z-System 運用プロトコル（デバッグループ）
過去のスクリプト依存（extract_errors.sh等）を廃止し、以下の決定論的ループを遵守する。

1. **Implementation**: 人間が1つの機能を指定し、AI(Cursor)に最小コードを実装させる。
2. **Playtest**: Zomboidを起動し、挙動を確認する。
3. **Log Extraction**: エラー発生時、`Console.txt` を開き、末尾の `{"Z_LOG": true...}` および直前の `{"Z_TRACE": true...}` の行を人間が直接コピーする。
4. **Patch Generation**: コピーしたJSONをそのままCursorのチャットに入力。AIは `.cursorrules` に従い、推論を含まない「最小差分 (Minimal Diff)」のみを提案する。
5. **Apply & Repeat**: 差分を適用し、再度テストを行う。

## 4. サーキットブレーカー (Stuck Rule)
- 同じ `Z_LOG` のIDが2回連続で発生した場合、AIはメインコードの修正を停止する。
- 代わりに、状態確認用の軽量な `print` コードを生成し、観測の解像度を強制的に引き上げる。