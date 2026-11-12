<#
  Common.ps1
  公共基础：路径解析、JSON 读写、带颜色的输出、用户输入。
  被 CodexSwitcher.ps1 通过 dot-source 加载，不直接运行。
#>

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------- 输出 ----------
function Write-Info    { param([string]$Text) Write-Host $Text }
function Write-Ok      { param([string]$Text) Write-Host $Text -ForegroundColor Green }
function Write-Warn    { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }
function Write-Err     { param([string]$Text) Write-Host $Text -ForegroundColor Red }
function Write-Dim     { param([string]$Text) Write-Host $Text -ForegroundColor DarkGray }
function Write-Heading { param([string]$Text) Write-Host ''; Write-Host $Text -ForegroundColor Cyan }

# ---------- 路径 ----------
<#
  解析所有运行期路径。状态放在 Codex 自己的目录（默认 ~/.codex/.switch），
  这样和 Codex 的 config.toml / auth.json 在一起，便于备份和排查。
#>
function Get-SwitcherPaths {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Join-Path $env:USERPROFILE '.codex'
    }
    $Root = [IO.Path]::GetFullPath($Root)

    $store = Join-Path $Root '.switch'
    return [pscustomobject]@{
        Root       = $Root
        Store      = $store
        Config     = Join-Path $Root  'config.toml'
        Auth       = Join-Path $Root  'auth.json'
        AccountAuth= Join-Path $store 'auth.account.json'
        Providers  = Join-Path $store 'providers.json'
        Keys       = Join-Path $store 'keys'
        State      = Join-Path $store 'state.txt'
        ProxyState = Join-Path $store 'proxy-state.txt'
    }
}

function Initialize-SwitcherStore {
    param($Paths)

    foreach ($d in @($Paths.Store, $Paths.Keys)) {
        if (-not (Test-Path -LiteralPath $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

# ---------- JSON ----------
function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Write-JsonFile {
    param([string]$Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($Path, $json, $script:Utf8NoBom)
}

function Read-TextFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Write-TextFile {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

# 读单行状态文件，空文件返回空串（避免 .Trim() 作用在 $null 上）
function Read-StateFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $c = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $c) { return '' }
    return $c.Trim()
}

function Write-StateFile {
    param([string]$Path, [string]$Value)
    Set-Content -LiteralPath $Path -Value $Value -Encoding ascii -NoNewline
}

# ---------- 输入 ----------
# 不回显地读一行（用于 API key）
function Read-SecretInput {
    param([string]$Prompt)

    $sec = Read-Host -AsSecureString $Prompt
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try   { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

# ---------- 等宽终端对齐 ----------
# 中文在控制台占两格，用 PadRight 会错位，所以按"显示宽度"补齐
function Get-DisplayWidth {
    param([string]$Text)

    $w = 0
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($code -ge 0x1100 -and (
                ($code -le 0x115F) -or
                ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
                ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
                ($code -ge 0xF900 -and $code -le 0xFAFF) -or
                ($code -ge 0xFE30 -and $code -le 0xFE4F) -or
                ($code -ge 0xFF00 -and $code -le 0xFF60) -or
                ($code -ge 0xFFE0 -and $code -le 0xFFE6))) {
            $w += 2
        } else {
            $w += 1
        }
    }
    return $w
}

function Format-Cell {
    param([string]$Text, [int]$Width)

    if ($null -eq $Text) { $Text = '' }
    $pad = $Width - (Get-DisplayWidth $Text)
    if ($pad -lt 0) { $pad = 0 }
    return ($Text + (' ' * $pad))
}
