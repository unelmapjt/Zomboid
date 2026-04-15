# Get-ZLog.ps1
# Zomboidの最新ログから Z_TRACE と Z_LOG のみを抽出し、クリップボードにコピーする

$logPath = "$env:USERPROFILE\Zomboid\Console.txt"

if (-Not (Test-Path $logPath)) {
    Write-Host "Console.txt が見つかりません: $logPath" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

try {
    # 最新の1000行から、我々のシステムが吐き出したJSONだけを抽出
    $lines = Get-Content $logPath -Tail 1000 -ErrorAction Stop
}
catch {
    Write-Host "Console.txt の読み取りに失敗しました: $logPath" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    Start-Sleep -Seconds 3
    exit 1
}

$extracted = $lines | Where-Object { $_ -match '"Z_TRACE":true' -or $_ -match '"Z_LOG":true' }

if ($extracted.Count -eq 0) {
    Write-Host "Z-System のログが見つかりませんでした。" -ForegroundColor Yellow
} else {
    # 抽出したログを結合してクリップボードにコピー
    $output = $extracted -join "`r`n"
    try {
        Set-Clipboard -Value $output -ErrorAction Stop
    }
    catch {
        Write-Host "クリップボードへのコピーに失敗しました。" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        Start-Sleep -Seconds 3
        exit 1
    }
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "抽出成功！以下のログをクリップボードにコピーしました。" -ForegroundColor Green
    Write-Host "Cursorに戻って Ctrl + V を押してください。" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host $output -ForegroundColor DarkGray
}

Start-Sleep -Seconds 2