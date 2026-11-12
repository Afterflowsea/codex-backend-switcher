@echo off
rem ============================================================
rem  Codex 后端切换器 - 菜单入口
rem  这个文件只负责起一个 PowerShell 窗口，真正的逻辑在 bin\menu.ps1
rem ============================================================
setlocal
title Codex Switcher
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0menu.ps1"
if errorlevel 1 (
    echo.
    echo 启动失败。请确认已运行 bin\install.ps1 完成安装。
    pause
)
endlocal
