<#
  menu.ps1
  交互式菜单：从 providers.json 动态生成，不写死站点，增删站点不用改这里。
  由 bin/switcher.bat 调起。
#>
$ErrorActionPreference = 'Stop'

$here     = $PSScriptRoot
$switcher = Join-Path (Split-Path $here -Parent) 'src\CodexSwitcher.ps1'
$store    = Join-Path $env:USERPROFILE '.codex\.switch'
$provFile = Join-Path $store 'providers.json'

# 复用主程序的等宽对齐工具（中文占两格）
. (Join-Path (Split-Path $switcher -Parent) 'lib\Common.ps1')

if (-not (Test-Path -LiteralPath $switcher)) {
    Write-Host '找不到 src\CodexSwitcher.ps1，目录结构可能不完整。' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $provFile)) {
    Write-Host ('找不到站点配置: ' + $provFile) -ForegroundColor Red
    Write-Host '请先运行 bin\install.ps1 完成安装。' -ForegroundColor Yellow
    exit 1
}

function Get-All {
    @(Get-Content -LiteralPath $provFile -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-CurrentId {
    $f = Join-Path $store 'state.txt'
    if (-not (Test-Path -LiteralPath $f)) { return '' }
    $c = Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue
    if ($null -eq $c) { return '' }
    return $c.Trim()
}

while ($true) {
    $provs = Get-All
    $cur   = Get-CurrentId

    Clear-Host
    Write-Host ''
    Write-Host '  ==============================================' -ForegroundColor DarkCyan
    Write-Host '            Codex 后端切换器' -ForegroundColor Cyan
    Write-Host '  ==============================================' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host ('   当前: ' + $(if ($cur) { ($provs | Where-Object { $_.id -eq $cur }).name } else { '未知' })) -ForegroundColor Gray
    Write-Host ''

    $i = 0
    $map = @{}
    foreach ($p in $provs) {
        $i++
        $map["$i"] = $p.id
        $mark = if ($p.id -eq $cur) { '*' } else { ' ' }
        $tag  = if ($p.kind -eq 'account') { '(官方账号)' } else { $p.base_url }
        Write-Host ('   ' + $mark + ' ' + $i + '. ' + (Format-Cell $p.name 16) + $tag)
    }

    Write-Host ''
    Write-Host '   0. 退出' -ForegroundColor DarkGray
    Write-Host ''
    $c = Read-Host '   选择'

    if ($c -eq '0' -or $c -eq '') { exit 0 }

    if (-not $map.ContainsKey($c)) {
        Write-Host '   无效选项' -ForegroundColor Red
        Start-Sleep -Milliseconds 700
        continue
    }

    $id = $map[$c]
    Write-Host ''

    # 用子进程调用，隔离 exit，菜单不会跟着退出
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $switcher $id

    Write-Host ''
    Read-Host '   按回车返回菜单' | Out-Null
}
