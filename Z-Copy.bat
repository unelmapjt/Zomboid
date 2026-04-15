@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0Get-ZLog.ps1"
if errorlevel 1 (
    echo ログの抽出に失敗しました。パスや権限を確認してください。
    pause
)