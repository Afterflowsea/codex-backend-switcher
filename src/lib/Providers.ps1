<#
  Providers.ps1
  站点清单（providers.json）的读写：当前站点状态、每个站点的模型记忆、key 文件位置。

  providers.json 结构：
  [
    {
      "id": "apimart",              # 唯一标识，也用作 config.toml 里的 model_provider 名
      "name": "apimart",            # 显示名
      "kind": "relay",              # account = 官方账号；relay = 第三方中转
      "base_url": "https://.../v1", # relay 必填；account 留空
      "model": "gpt-6.1-sol",       # 该站点默认模型，切换时写入 config.toml
      "proxy": "http://127.0.0.1:7890",  # 需要翻墙的站点填代理，直连留空
      "extra": { "web_search": "live" }, # 可选：该站点附加的根级配置项
      "note": "备注"
    }
  ]
#>

function Get-Providers {
    param($Paths)

    if (-not (Test-Path -LiteralPath $Paths.Providers)) {
        throw "找不到站点配置文件：$($Paths.Providers)"
    }
    $list = Read-JsonFile $Paths.Providers
    if ($null -eq $list) { throw "站点配置文件为空或格式错误：$($Paths.Providers)" }
    return @($list)
}

function Get-Provider {
    param($Paths, [string]$Id)

    $list = Get-Providers $Paths
    return ($list | Where-Object { $_.id -eq $Id } | Select-Object -First 1)
}

function Save-Providers {
    param($Paths, $List)
    Write-JsonFile $Paths.Providers $List
}

<#
  记住某个站点最后一次使用的模型。
  Codex 的界面改模型会直接改写 config.toml，所以切走之前要把它记到 providers.json，
  否则切回来就丢了你选过的模型。
#>
function Save-ProviderModel {
    param($Paths, [string]$Id, [string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) { return }
    $list = Get-Providers $Paths
    $changed = $false
    foreach ($p in $list) {
        if ($p.id -eq $Id -and $p.model -ne $Model) {
            $p.model = $Model
            $changed = $true
        }
    }
    if ($changed) { Save-Providers $Paths $list }
}

# ---------- 当前站点 ----------
function Get-CurrentMode {
    param($Paths)
    return (Read-StateFile $Paths.State)
}

function Set-CurrentMode {
    param($Paths, [string]$Id)
    Write-StateFile $Paths.State $Id
}

# ---------- API key 存取 ----------
function Get-KeyFile {
    param($Paths, [string]$Id)
    return (Join-Path $Paths.Keys ($Id + '.key'))
}

function Read-Key {
    param($Paths, [string]$Id)
    $f = Get-KeyFile $Paths $Id
    if (-not (Test-Path -LiteralPath $f)) { return '' }
    return ((Get-Content -LiteralPath $f -Raw).Trim())
}

function Write-Key {
    param($Paths, [string]$Id, [string]$Key)
    Write-TextFile (Get-KeyFile $Paths $Id) $Key
}

function Remove-Key {
    param($Paths, [string]$Id)
    $f = Get-KeyFile $Paths $Id
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}

# 所有站点 extra 里出现过的根级配置键名，切换时用于清理
function Get-ExtraKeys {
    param($Paths)

    $keys = @()
    foreach ($p in (Get-Providers $Paths)) {
        if ($p.extra) {
            foreach ($pr in $p.extra.PSObject.Properties) { $keys += $pr.Name }
        }
    }
    return @($keys | Select-Object -Unique)
}
