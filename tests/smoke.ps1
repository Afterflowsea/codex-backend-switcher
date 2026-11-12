<#
  smoke.ps1
  离线冒烟测试：不联网、不碰真实 ~/.codex。
  验证核心逻辑（配置改写、状态读写、CLI 的 list/status）没有回归。

  用法：
    powershell -ExecutionPolicy Bypass -File .\tests\smoke.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# 统一编码，避免在英文系统/CI 上中文断言失败
try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $OutputEncoding = [Text.Encoding]::UTF8
} catch { }

$repoRoot = Split-Path $PSScriptRoot -Parent
$libDir   = Join-Path $repoRoot 'src\lib'
$entry    = Join-Path $repoRoot 'src\CodexSwitcher.ps1'

$pass = 0
$fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)

    if ($Condition) {
        Write-Host ('  [PASS] ' + $Name) -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host ('  [FAIL] ' + $Name) -ForegroundColor Red
        $script:fail++
    }
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Name)
    Assert-True ($Text -match $Pattern) $Name
}

Write-Host ''
Write-Host '  Codex 后端切换器 - 冒烟测试' -ForegroundColor Cyan
Write-Host ''

# ---------- 准备一个隔离的假 CODEX_HOME ----------
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-switcher-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$store = Join-Path $temp '.switch'
New-Item -ItemType Directory -Path $store -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $store 'keys') -Force | Out-Null

$utf8 = New-Object Text.UTF8Encoding($false)

# 假 config.toml：故意带上用户自己的设置，测试是否被保留
$configToml = @'
model = "gpt-6-luna"
sandbox_mode = "danger-full-access"

[projects.'c:\users\someone']
trust_level = "trusted"

[desktop]
appearanceTheme = "system"
'@
[IO.File]::WriteAllText((Join-Path $temp 'config.toml'), $configToml, $utf8)

# 假 providers.json
$providers = @'
[
  { "id": "account", "name": "ChatGPT 账号", "kind": "account", "base_url": "", "model": "gpt-6-luna", "proxy": "", "extra": {} },
  { "id": "relay-a", "name": "中转A", "kind": "relay", "base_url": "https://a.example.com/v1", "model": "gpt-6.1-sol", "proxy": "", "extra": {} },
  { "id": "relay-b", "name": "中转B", "kind": "relay", "base_url": "https://b.example.com", "model": "gpt-5.6-sol", "proxy": "http://127.0.0.1:7890", "extra": { "web_search": "live" } }
]
'@
[IO.File]::WriteAllText((Join-Path $store 'providers.json'), $providers, $utf8)

# ---------- 加载模块 ----------
foreach ($m in @('Common', 'Providers', 'CodexConfig', 'Auth', 'Network', 'Proxy', 'App')) {
    . (Join-Path $libDir ($m + '.ps1'))
}

$paths = Get-SwitcherPaths -Root $temp

Write-Host '  1. 路径与站点解析'
Assert-True ($paths.Config -like '*config.toml') '解析出 config.toml 路径'
$list = Get-Providers $paths
Assert-True ($list.Count -eq 3) '读到 3 个站点'
Assert-True ((Get-Provider $paths 'relay-b').model -eq 'gpt-5.6-sol') '按 id 取到站点'

Write-Host ''
Write-Host '  2. 状态与 key'
Set-CurrentMode $paths 'relay-a'
Assert-True ((Get-CurrentMode $paths) -eq 'relay-a') '当前站点写入/读出一致'
Write-Key $paths 'relay-a' 'sk-test-123'
Assert-True ((Read-Key $paths 'relay-a') -eq 'sk-test-123') 'key 写入/读出一致'
Remove-Key $paths 'relay-a'
Assert-True ((Read-Key $paths 'relay-a') -eq '') 'key 删除生效'

Write-Host ''
Write-Host '  3. config.toml 改写'
$text = [IO.File]::ReadAllText($paths.Config, [Text.Encoding]::UTF8)
$pA   = Get-Provider $paths 'relay-a'

$text = Set-ProviderConfig -Text $text -Provider $pA -ExtraKeys @('web_search')
Assert-Match $text '(?m)^model_provider = "relay-a"' '写入 model_provider'
Assert-Match $text '(?m)^\[model_providers\.relay-a\]' '写入 provider 表'
Assert-Match $text '(?m)^base_url = "https://a.example.com/v1"' '写入 base_url'
Assert-Match $text '(?m)^model = "gpt-6\.1-sol"' '写入 model'
Assert-Match $text '(?m)^review_model = "gpt-6\.1-sol"' 'review_model 跟随'
Assert-Match $text '\[projects\.' '保留用户自己的 [projects] 段'
Assert-Match $text 'appearanceTheme' '保留 [desktop] 段'

Write-Host ''
Write-Host '  4. 站点互切（清旧、加新、清 extra）'
$pB = Get-Provider $paths 'relay-b'
$text = Set-ProviderConfig -Text $text -Provider $pB -ExtraKeys @('web_search')
Assert-Match $text '(?m)^model_provider = "relay-b"' '切到 relay-b'
Assert-True (-not ($text -match 'model_provider = "relay-a"')) '旧的 model_provider 已清除'
Assert-True (-not ($text -match '\[model_providers\.relay-a\]')) '旧的 provider 表已清除'
Assert-Match $text '(?m)^web_search = "live"' '写入 extra 键'

$pA = Get-Provider $paths 'relay-a'
$text = Set-ProviderConfig -Text $text -Provider $pA -ExtraKeys @('web_search')
Assert-True (-not ($text -match '(?m)^web_search')) '切走后 extra 键被清理'

Write-Host ''
Write-Host '  5. 切回账号（不写 provider 块）'
$pAccount = Get-Provider $paths 'account'
$text = Set-ProviderConfig -Text $text -Provider $pAccount -ExtraKeys @('web_search')
Assert-True (-not ($text -match '(?m)^model_provider')) '账号模式无 model_provider'
Assert-True (-not ($text -match '\[model_providers\.')) '账号模式无 provider 表'
Assert-Match $text '(?m)^model = "gpt-6-luna"' '模型回到账号默认值'

Write-Host ''
Write-Host '  6. 凭据'
[IO.File]::WriteAllText($paths.Auth, '{"auth_mode":"apikey","OPENAI_API_KEY":"sk-x"}', $utf8)
Assert-True ((Get-AuthMode $paths) -eq 'apikey') 'apikey 模式可读'
Assert-True ((Save-AccountAuth $paths) -eq $false) 'apikey 不会被当成账号凭据备份'

[IO.File]::WriteAllText($paths.Auth, '{"auth_mode":"chatgpt","tokens":{"refresh_token":"r"}}', $utf8)
Assert-True ((Save-AccountAuth $paths) -eq $true) '账号凭据备份成功'
Set-ApiKeyAuth $paths 'sk-new'
Assert-True ((Get-AuthMode $paths) -eq 'apikey') '可切换为 apikey'
Assert-True ((Restore-AccountAuth $paths) -eq $true) '可还原账号凭据'
Assert-True ((Get-AuthMode $paths) -eq 'chatgpt') '还原后是 chatgpt 模式'

Write-Host ''
Write-Host '  7. 模型挑选'
Assert-True ((Get-TextModels @('gpt-6-luna','gpt-image-1','sora_image')) -join ',' -eq 'gpt-6-luna') '过滤图像模型'
Assert-True ((Select-BestModel @('gpt-6-luna','gpt-5.6-sol') 'gpt-5.6-sol') -eq 'gpt-5.6-sol') '尊重站点指定的模型'
Assert-True ((Select-BestModel @('gpt-5.2','gpt-6') '') -eq 'gpt-6') '没有指定时按优先级挑'

Write-Host ''
Write-Host '  8. CLI（子进程，隔离配置目录）'
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry list -Root $temp 2>&1 | Out-String
Assert-Match $out 'relay-a' 'list 能列出站点'

$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry status -Root $temp 2>&1 | Out-String
Assert-Match $out '当前站点' 'status 能输出当前站点'

$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry no-such-id -Root $temp 2>&1 | Out-String
Assert-True ($LASTEXITCODE -ne 0) '未知站点返回非 0'

Write-Host ''
Write-Host '  9. 文件编码（.ps1 必须 UTF-8 with BOM）'
$noBom = @()
Get-ChildItem $repoRoot -Recurse -Filter *.ps1 | ForEach-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)
    $hasBom = ($b.Length -ge 3) -and ($b[0] -eq 0xEF) -and ($b[1] -eq 0xBB) -and ($b[2] -eq 0xBF)
    if (-not $hasBom) { $noBom += $_.Name }
}
$msg = '所有 .ps1 带 BOM'
if ($noBom.Count -gt 0) { $msg += '（缺: ' + ($noBom -join ', ') + '）' }
Assert-True ($noBom.Count -eq 0) $msg

# ---------- 清理 ----------
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host ('  结果: ' + $pass + ' 通过, ' + $fail + ' 失败') -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
Write-Host ''

if ($fail -gt 0) { exit 1 }
exit 0
