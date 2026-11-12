<#
  uninstall.ps1
  卸载：删除程序文件和桌面快捷方式。
  默认保留 ~/.codex/.switch 里的状态（providers.json、key、账号凭据备份）。
  想连状态一起删，加 -PurgeState。
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'CodexSwitcher'),
    [string]$CodexRoot  = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$PurgeState
)

$ErrorActionPreference = 'Stop'

$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex 切换.lnk'
if (Test-Path -LiteralPath $lnk) {
    Remove-Item -LiteralPath $lnk -Force
    Write-Host '  已删除桌面快捷方式' -ForegroundColor Green
}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-Host ('  已删除程序目录: ' + $InstallDir) -ForegroundColor Green
}

$store = Join-Path $CodexRoot '.switch'
if ($PurgeState -and (Test-Path -LiteralPath $store)) {
    Write-Host ''
    Write-Host ('  即将删除状态目录（含 key 与登录备份）: ' + $store) -ForegroundColor Yellow
    $ans = Read-Host '  确认删除？输入 yes'
    if ($ans -eq 'yes') {
        Remove-Item -LiteralPath $store -Recurse -Force
        Write-Host '  已删除状态目录' -ForegroundColor Green
    } else {
        Write-Host '  已跳过，状态保留' -ForegroundColor DarkGray
    }
} elseif (Test-Path -LiteralPath $store) {
    Write-Host ('  状态保留在: ' + $store) -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  卸载完成。' -ForegroundColor Cyan
