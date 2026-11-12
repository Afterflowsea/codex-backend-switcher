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

function Stop-CodexApp {
    param([int]$WaitMs = 1500)

    $procs = Get-RunningAppProcesses
    if ($procs.Count -eq 0) { return 0 }

    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds $WaitMs
    return $procs.Count
}

function Start-CodexApp {
    param([string]$WorkDir = $env:USERPROFILE)

    $exe = Get-CodexExe
    if (-not $exe) { return $false }

    Start-Process -FilePath $exe -ArgumentList 'app' -WorkingDirectory $WorkDir | Out-Null
    return $true
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
