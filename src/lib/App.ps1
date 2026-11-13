<#
  App.ps1
  和 Codex 桌面端进程打交道：找到可执行文件、判断是否在运行、关闭、重新打开、拉起登录。

  为什么切换前必须关闭：Codex 退出时会把内存里的设置写回 config.toml，
  如果先改文件再让它退出，刚写进去的配置会被覆盖掉。
#>

# 定位 codex.exe：优先 PATH，其次 %LOCALAPPDATA%\OpenAI\Codex\bin
function Get-CodexExe {
    $c = Get-Command 'codex.exe' -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }

    $bin = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $bin) {
        $f = Get-ChildItem -Path $bin -Recurse -Filter 'codex.exe' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

function Get-RunningAppProcesses {
    return @(Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue)
}

<#
  定位桌面端主程序（MSIX 包里的 app\ChatGPT.exe）。
  优先按包信息查，避免把版本号写死；查不到再扫 WindowsApps 目录。
  为什么不用 codex app：那个命令会先跑一轮 CLI 检查再拉起界面，
  实测多花约 6 秒（7.4s vs 13.5s）。
#>
function Get-CodexAppExe {
    $pkg = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
           Sort-Object Version -Descending | Select-Object -First 1

    if ($pkg -and $pkg.InstallLocation) {
        $p = Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }

    $wa = Join-Path $env:ProgramFiles 'WindowsApps'
    if (Test-Path -LiteralPath $wa) {
        foreach ($d in (Get-ChildItem -Path $wa -Directory -Filter 'OpenAI.Codex_*' -ErrorAction SilentlyContinue |
                        Sort-Object Name -Descending)) {
            $c = Join-Path $d.FullName 'app\ChatGPT.exe'
            if (Test-Path -LiteralPath $c) { return $c }
        }
    }
    return $null
}

function Stop-CodexApp {
    param([int]$WaitMs = 1500)

    $procs = Get-RunningAppProcesses
    if ($procs.Count -eq 0) { return 0 }

    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds $WaitMs
    return $procs.Count
}

function Start-CodexApp {
    param(
        [string]$WorkDir = $env:USERPROFILE,
        # 强制走 codex app 包装器（默认优先直连主程序）
        [switch]$PreferCli
    )

    # 直接启动 MSIX 主程序比 codex app 快约 6 秒（实测 7.4s vs 13.5s）：
    # codex app 会先做一轮 CLI 侧的检查/握手，然后才拉起界面。
    if (-not $PreferCli) {
        $app = Get-CodexAppExe
        if ($app) {
            Start-Process -FilePath $app -WorkingDirectory $WorkDir | Out-Null
            return $app
        }
    }

    $exe = Get-CodexExe
    if (-not $exe) { return $null }

    Start-Process -FilePath $exe -ArgumentList 'app' -WorkingDirectory $WorkDir | Out-Null
    return $exe
}

<#
  账号模式没有可用凭据时拉起 device code 登录。
  注意：浏览器授权必须由用户本人点，脚本只能替你把页面打开、把验证码显示出来。
#>
function Start-CodexLogin {
    $exe = Get-CodexExe
    if (-not $exe) { return $false }

    Start-Process 'https://auth.openai.com/codex/device' | Out-Null
    & $exe login --device-auth
    return $true
}
