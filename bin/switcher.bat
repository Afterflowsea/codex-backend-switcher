@echo off
rem ============================================================
rem  Codex backend switcher - menu launcher
rem  This file only starts a PowerShell window; logic lives in bin\menu.ps1
rem
rem  IMPORTANT: keep this file ASCII-only with CRLF line endings.
rem  cmd.exe misparses non-ASCII bytes when the file uses LF-only endings,
rem  which shows up as errors like "'x' is not recognized as a command".
rem ============================================================
setlocal
title Codex Switcher
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0menu.ps1"
if errorlevel 1 (
    echo.
    echo Failed to start. Run bin\install.ps1 first, or check the PowerShell output above.
    pause
)
endlocal
