<#
  install.ps1
  把程序装到本机并创建桌面快捷方式。

  设计上把"程序文件"和"运行状态"分开放：
    程序  -> %LOCALAPPDATA%\CodexSwitcher     （可随时覆盖升级）
    状态  -> %USERPROFILE%\.codex\.switch     （providers.json / key / 登录备份，升级不丢）
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'CodexSwitcher'),
    [string]$CodexRoot  = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$NoShortcut
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

Write-Host ''
Write-Host '  Codex 后端切换器 - 安装' -ForegroundColor Cyan
Write-Host ('  程序目录: ' + $InstallDir)
Write-Host ('  状态目录: ' + (Join-Path $CodexRoot '.switch'))
Write-Host ''

# ---------- 1. 复制程序文件 ----------
if (Test-Path -LiteralPath $InstallDir) {
    Write-Host '  检测到已安装，覆盖程序文件（状态不受影响）…' -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

foreach ($item in @('src', 'bin', 'assets')) {
    $src = Join-Path $repoRoot $item
    if (-not (Test-Path -LiteralPath $src)) { throw "缺少目录: $src" }
    $dst = Join-Path $InstallDir $item
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
}

# .bat 必须是 CRLF 且纯 ASCII：cmd.exe 在 LF 换行 + 非 ASCII 字节时会解析错乱，
# 表现为 "'x' is not recognized as an internal or external command"，双击无任何反应。
# 仓库里已经保证，这里再兜一次底，避免 clone 时的换行转换把文件搞坏。
foreach ($b in (Get-ChildItem -Path (Join-Path $InstallDir 'bin') -Filter '*.bat' -ErrorAction SilentlyContinue)) {
    $t = [IO.File]::ReadAllText($b.FullName, [Text.Encoding]::UTF8)
    $t = ($t -replace "`r?`n", "`r`n")
    [IO.File]::WriteAllText($b.FullName, $t, (New-Object Text.UTF8Encoding($false)))
}
Write-Host '  [1/3] 程序文件已就位' -ForegroundColor Green

# ---------- 2. 初始化状态目录 ----------
$store = Join-Path $CodexRoot '.switch'
foreach ($d in @($store, (Join-Path $store 'keys'))) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$provFile = Join-Path $store 'providers.json'
if (-not (Test-Path -LiteralPath $provFile)) {
    $example = Join-Path $repoRoot 'config\providers.example.json'
    Copy-Item -LiteralPath $example -Destination $provFile -Force
    Write-Host '  [2/3] 已生成 providers.json（示例，请按需修改）' -ForegroundColor Green
} else {
    Write-Host '  [2/3] 保留现有 providers.json' -ForegroundColor Green
}

# ---------- 3. 桌面快捷方式 ----------
if (-not $NoShortcut) {
    $icon = Join-Path $InstallDir 'assets\icon\codex-switch.ico'
    $bat  = Join-Path $InstallDir 'bin\switcher.bat'
    $lnk  = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex 切换.lnk'

    $sh = New-Object -ComObject WScript.Shell
    $sc = $sh.CreateShortcut($lnk)
    $sc.TargetPath       = $bat
    $sc.WorkingDirectory = Split-Path $bat -Parent
    $sc.Description      = '切换 Codex 的后端（账号 / 各中转站）'
    if (Test-Path -LiteralPath $icon) { $sc.IconLocation = $icon + ',0' }
    $sc.Save()
    Write-Host '  [3/3] 桌面快捷方式已创建' -ForegroundColor Green
}

Write-Host ''
Write-Host '  安装完成。' -ForegroundColor Cyan
Write-Host ''
Write-Host '  下一步：'
Write-Host ('    1. 编辑站点清单: ' + $provFile)
Write-Host '       把 base_url / model / proxy 改成你自己的'
Write-Host '    2. 双击桌面「Codex 切换」图标'
Write-Host '    3. 首次切到某个中转时，会提示你粘贴一次 API key'
Write-Host ''
