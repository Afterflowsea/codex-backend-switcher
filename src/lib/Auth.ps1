<#
  Auth.ps1
  管理 Codex 的登录凭据 ~/.codex/auth.json。

  Codex 只有"一个"凭据槽位，所以账号登录和 API key 登录互斥：
    { "auth_mode": "apikey",  "OPENAI_API_KEY": "sk-..." }
    { "auth_mode": "chatgpt", "tokens": { ... } }

  切换账号模式时不需要重新登录——只要把之前保存的 tokens 还原即可。
  这也是本项目能做到"切回账号不用再扫码"的关键。
#>

function Get-AuthMode {
    param($Paths)

    $j = Read-JsonFile $Paths.Auth
    if ($null -eq $j) { return '' }
    return [string]$j.auth_mode
}

# 写入 API key 形式的凭据
function Set-ApiKeyAuth {
    param($Paths, [string]$Key)

    $json = '{"auth_mode":"apikey","OPENAI_API_KEY":"' + $Key + '"}'
    Write-TextFile $Paths.Auth $json
}

# 把当前的账号凭据（chatgpt tokens）备份起来，切走之前调用
function Save-AccountAuth {
    param($Paths)

    if (-not (Test-Path -LiteralPath $Paths.Auth)) { return $false }
    if ((Get-AuthMode $Paths) -ne 'chatgpt') { return $false }

    Copy-Item -LiteralPath $Paths.Auth -Destination $Paths.AccountAuth -Force
    return $true
}

# 还原账号凭据；没有备份则返回 $false（调用方应引导用户登录）
function Restore-AccountAuth {
    param($Paths)

    if (-not (Test-Path -LiteralPath $Paths.AccountAuth)) { return $false }
    Copy-Item -LiteralPath $Paths.AccountAuth -Destination $Paths.Auth -Force
    return $true
}

function Test-AccountAuthSaved {
    param($Paths)
    return (Test-Path -LiteralPath $Paths.AccountAuth)
}
