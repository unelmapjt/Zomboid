# Negative Context (Blacklist) - Project Zomboid Build 42

このファイルは、開発中に判明した「ビルド 42 (42.16.x以降) において使用を避けるべき、または極めて不安定なコード・API」を記録するためのものです。

## 1. カメラ・ズーム制御 (Camera & Zoom)

B42 のカメラは「Object（静的な状態）」ではなく「Process（連続的な解決処理）」に移行しているため、直接的な操作は推奨されません。

- **`getCore():setZoom(value)`** / **`setNextZoom(value)`**: 
    - **問題**: 引数不足エラー（expected 2, got 1）が発生する。B42 では `(playerIndex, value)` の形式が必須。
    - **リスク**: セットしてもエンジンの `AutoZoom` や車両・室内補正に即座に上書きされ、カクつきや「引き戻し」が発生する。
- **`IsoCamera.cameras[0].zoom = value` (直接代入)**:
    - **問題**: `cameras[]` はレンダラー用のスナップショット（キャッシュ）であり、ここを書き換えてもシミュレーション層のカメラ状態は変わらない。
    - **リスク**: マルチプレイヤーでの同期崩壊や、フレームごとの激しいジッターを引き起こす。
- **`getCore():doZoomScroll(0, 0)` (同期目的の連打)**:
    - **問題**: 本来は入力イベント用のトリガーであり、常用するとエンジン側のズームキューが再生成され続け、意図した動作を妨害する。

## 2. 視覚演出・UI (Visuals & UI)

- **`UIManager.FadeIn()`** / **`FadeOut()`**:
    - **問題**: インゲーム開始直後に呼び出すと、Java 側で `KahluaTableImpl` 型不一致エラーや、画面が永久に黒くなる現象が発生する。
- **`getCore():setFadeBeforeUI(value)`**:
    - **問題**: レガシー API。B42 環境下での動作が極めて不安定。

## 3. Lua/Java 呼び出し規約 (API Invocation)

- **無引数の Java メソッドを `:` (コロン) で呼び出す**:
    - **例**: `getCore():getMaxZoom()`
    - **問題**: `expected 0 arguments, got 1` エラー。`:` 呼び出しは暗黙的に `self` (Coreインスタンス) を渡すため、引数 0 本の Java 関数にとっては「余計な引数が届いた」ことになる。
    - **対策**: `getCore().getMaxZoom()` のようにドット形式で呼び出す。

## 4. エンティティ生成 (Entity Spawning)

- **`IsoDeadBody.new(getCell())`**:
    - **問題**: 座標情報を持たない遺体を生成してしまい、レンダリングループ (`FBORenderCell`) で NullPointerException (NPE) によるクラッシュを引き起こす。
    - **対策**: 必ず `createZombie` で一度キャラクターを生成し、`IsoDeadBody.new(zombie, false)` を使用すること。
- **`isoGridSquare:addCorpse()`**:
    - **問題**: バニラ B42 の Lua には露出していないメソッド。
- **`isoDeadBody:getInventory()`**:
    - **問題**: `IsoDeadBody` クラスは `IsoGameCharacter` を継承しているが、Lua 側からはインベントリに直接アクセスできない場合が多い。
    - **対策**: 遺体に変換する前の `zombie` オブジェクトから `getInventory()` を呼び出して中身を操作する。

## 5. 背景・タイトル描画 (Intro Rendering)

- **インゲーム中の `MainScreen:prerender` 改変**:
    - **リスク**: タイトル画面の背景描画をインゲーム中も実行しようとすると、世界がタイトル背景で塗りつぶされ（Blackout現象）、HUD しか見えない状態になる。ガーディングが必須。
