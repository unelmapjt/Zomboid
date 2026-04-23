# Zomboid DebugLog 末尾追従（コンソールを開いたまま新規行を表示）
# 新しいゲームセッションで別ファイルになったら、一度 Ctrl+C で止めて再実行してください。
#
# 使い方:
#   .\watch_debug_log.ps1
#   .\watch_debug_log.ps1 -Tail 200
#   .\watch_debug_log.ps1 -NeOnly
#   .\watch_debug_log.ps1 -MatchOnly 'NE_|NOX_|Z_TRACER|ERROR|Exception'

param(
    [int]$Tail = 120,
    [string]$MatchOnly = '',
    [switch]$NeOnly
)

$ErrorActionPreference = 'Stop'
$logRoot = Join-Path $PSScriptRoot 'Logs'
if (-not (Test-Path $logRoot)) {
    Write-Host "Logs フォルダがありません: $logRoot" -ForegroundColor Red
    exit 1
}

if ($NeOnly) {
    $MatchOnly = 'NE_|NOX_|Z_TRACER|ERROR|Exception'
}

$latest = Get-ChildItem -Path $logRoot -Recurse -Filter '*DebugLog*.txt' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latest) {
    Write-Host "DebugLog が見つかりません: $logRoot" -ForegroundColor Red
    exit 1
}

Write-Host "監視中: $($latest.FullName)" -ForegroundColor Cyan
Write-Host "終了: Ctrl+C`n" -ForegroundColor DarkGray

if ($MatchOnly -ne '') {
    Get-Content -LiteralPath $latest.FullName -Tail $Tail -Wait |
        Where-Object { $_ -match $MatchOnly } |
        ForEach-Object { Write-Host $_ }
}
else {
    Get-Content -LiteralPath $latest.FullName -Tail $Tail -Wait |
        ForEach-Object { Write-Host $_ }
}
