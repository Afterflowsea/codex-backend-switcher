<#
  Proxy.ps1
  按站点设置/清除用户级代理环境变量。

  为什么需要：Windows 的"系统代理"开关只对读 WinINET 的程序（浏览器等）生效，
  Codex / curl 这类程序默认不看它，而是看 HTTPS_PROXY 环境变量。
  所以需要翻墙的站点，光开着系统代理是不够的。
#>

$script:ProxyVars = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')

function Get-ProxyState {
    param($Paths)
    return (Read-StateFile $Paths.ProxyState)
}

# 传空字符串表示清除
function Set-UserProxy {
    param([string]$Url)

    foreach ($v in $script:ProxyVars) {
        if ($Url) { [Environment]::SetEnvironmentVariable($v, $Url, 'User') }
        else      { [Environment]::SetEnvironmentVariable($v, $null, 'User') }
    }
}

# 只管理"本工具设置过"的变量：来自 state 文件的记录，不碰用户自己配的
function Update-Proxy {
    param($Paths, [string]$NewProxy)

    $prev = Get-ProxyState $Paths
    if ($prev -eq $NewProxy) { return $false }

    Set-UserProxy $NewProxy
    Write-StateFile $Paths.ProxyState $NewProxy
    return $true
}

# 当前进程能看到的代理（用于诊断输出）
function Get-EffectiveProxy {
    foreach ($v in $script:ProxyVars) {
        $val = [Environment]::GetEnvironmentVariable($v, 'User')
        if ($val) { return $val }
    }
    return ''
}
