<#
  CodexSwitcher.ps1  —— 入口
  在"ChatGPT 账号"和多个第三方中转之间切换 Codex 的后端。

  用法：
    CodexSwitcher.ps1 list                列出站点
    CodexSwitcher.ps1 status              当前站点与登录态
    CodexSwitcher.ps1 <站点id>            切换（默认会关闭并重新打开 Codex）
    CodexSwitcher.ps1 <站点id> -NoClose   只改文件，不动进程（调试用）
    CodexSwitcher.ps1 <站点id> -Yes       跳过关闭前的确认

  可选：
    -Root <目录>     Codex 配置目录，默认 ~/.codex
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Target = 'list',

    [string]$Root,

    [switch]$NoClose,
    [switch]$NoLaunch,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('Common', 'Providers', 'CodexConfig', 'Auth', 'Network', 'Proxy', 'App')) {
    . (Join-Path $libDir ($m + '.ps1'))
}

$paths = Get-SwitcherPaths -Root $Root
Initialize-SwitcherStore -Paths $paths

$cmd = $Target.ToLowerInvariant()

# ============================================================
# list / status
# ============================================================
if ($cmd -eq 'list') {
    $cur   = Get-CurrentMode $paths
    $provs = Get-Providers $paths

    Write-Host ''
    Write-Host ('    ' + (Format-Cell 'ID' 12) + (Format-Cell '名称' 18) + (Format-Cell '接口' 36) + '状态')
    Write-Host ('    ' + ('-' * 78))
    foreach ($p in $provs) {
        $mark = ' '
        if ($p.id -eq $cur) { $mark = '*' }

        if ($p.kind -eq 'account') {
            $state = if (Test-AccountAuthSaved $paths) { '账号凭据已保存' } else { '未登录' }
        } else {
            $state = if (Test-Path -LiteralPath (Get-KeyFile $paths $p.id)) { 'key 已保存' } else { '缺 key' }
        }

        $url = if ($p.base_url) { $p.base_url } else { '(官方)' }
        Write-Host ('  ' + $mark + ' ' + (Format-Cell $p.id 12) + (Format-Cell $p.name 18) + (Format-Cell $url 36) + $state)
    }
    Write-Host ''
    exit 0
}

if ($cmd -eq 'status') {
    $cur = Get-CurrentMode $paths
    $p   = $null
    if ($cur) { $p = Get-Provider $paths $cur }

    if ($p) {
        if ($p.base_url) { Write-Info ('当前站点 : ' + $p.name + '   ' + $p.base_url) }
        else             { Write-Info ('当前站点 : ' + $p.name) }
    } else {
        Write-Info '当前站点 : 未知（尚未通过本工具切换过）'
    }

    $mode = Get-AuthMode $paths
    Write-Info ('登录方式 : ' + $(if ($mode) { $mode } else { '未登录' }))

    $px = Get-ProxyState $paths
    Write-Info ('代理变量 : ' + $(if ($px) { $px } else { '(未设置)' }))

    $cfgText = Read-TextFile $paths.Config
    if ($cfgText) { Write-Info ('当前模型 : ' + (Get-ConfigModel $cfgText)) }
    exit 0
}

# ============================================================
# 解析目标站点
# ============================================================
$provider = Get-Provider $paths $cmd
if (-not $provider) {
    Write-Err ('未知站点: ' + $Target)
    Write-Info '可用站点请运行: CodexSwitcher.ps1 list'
    exit 2
}

$current = Get-CurrentMode $paths

# ============================================================
# 第一步：先校验，再动任何文件
# ============================================================
$key        = ''
$model      = [string]$provider.model
$needLogin  = $false

if ($provider.kind -eq 'relay') {

    if ([string]::IsNullOrWhiteSpace($provider.base_url)) {
        Write-Err ('站点 ' + $provider.id + ' 缺少 base_url，请检查 providers.json')
        exit 1
    }

    # --- 取 key ---
    $key = Read-Key $paths $provider.id
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Heading ('需要「' + $provider.name + '」的 API key（只输入一次，保存在本机）')
        $key = (Read-SecretInput '粘贴 key（不回显）').Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            Write-Err '没有输入，已取消（未做任何改动）。'
            exit 1
        }
    }

    # --- 校验连通性 + 模型 ---
    Write-Dim ('校验 ' + $provider.base_url + ' ...')
    $res    = Get-ModelList -BaseUrl $provider.base_url -Key $key -ProxyUrl $provider.proxy

    if (-not $res.ok) {
        Write-Err ''
        Write-Err '连不通或 key 无效，已取消，当前配置未改动。'
        Write-Err ('  厂商/系统返回: ' + $res.error)
        if ($provider.proxy) { Write-Warn ('  已尝试代理: ' + $provider.proxy) }
        else                 { Write-Warn '  该站点走直连；若域名被墙，请在 providers.json 给它配 proxy' }
        exit 1
    }

    $textModels = Get-TextModels $res.models

    # 模型列表里没有文本模型时，别急着下结论——直接发一次真实请求来判定
    if ($textModels.Count -eq 0) {
        Write-Warn ('「' + $provider.name + '」的模型列表里只有图像类模型：')
        Write-Warn ('  ' + (($res.models | Select-Object -First 8) -join ', '))
        Write-Dim  '  直接试一发文本请求再确认…'

        $probe = Test-TextModel -BaseUrl $provider.base_url -Key $key -Model $model -ProxyUrl $provider.proxy
        if ($probe.ok) {
            Write-Ok '  实际可以对话（模型列表不全），继续切换。'
            $textModels = @($model)
        } else {
            Write-Err ''
            Write-Err '不能当 Codex 后端，已取消，配置未改动。'
            Write-Err ('  厂商回复: ' + $probe.message)
            Write-Warn '  若提示 "not supported ... in this group"，说明这把 key 的「分组」里没有文本模型账号。'
            Write-Warn '  余额不足的报错不是这个，请去站点后台看 key 的分组/模型权限。'
            exit 1
        }
    }

    $model = Select-BestModel -Models $textModels -Preferred $provider.model
    if (-not $model) {
        Write-Err '没能在模型列表里找到可用模型，已取消。'
        exit 1
    }

    Save-ProviderModel -Paths $paths -Id $provider.id -Model $model
    Write-Ok ('  OK：共 ' + $res.models.Count + ' 个模型（文本 ' + $textModels.Count + '），选用 ' + $model)

} else {
    # 账号模式：有保存的 tokens 就不需要再登录
    if (-not (Test-AccountAuthSaved $paths)) { $needLogin = $true }
}

# ============================================================
# 第二步：关闭 Codex（它退出时会把设置写回 config.toml）
# ============================================================
$running = Get-RunningAppProcesses
if ($running.Count -gt 0 -and -not $NoClose) {
    Write-Warn ''
    Write-Warn ('需要关闭 Codex（' + $running.Count + ' 个进程）才能安全替换配置。')
    Write-Warn '未发送的输入会丢失。'

    if (-not $Yes) {
        $ans = Read-Host '回车继续，输入 n 取消'
        if ($ans -match '^[nN]') { Write-Info '已取消，未做改动。'; exit 1 }
    }
    $n = Stop-CodexApp
    Write-Dim ('  已关闭 ' + $n + ' 个进程')
}

# ============================================================
# 第三步：写 config / auth / 代理 / 状态
# ============================================================
# 切走之前，记住当前站点的模型（App 里改过的话就存下来）
$cfgText  = Read-TextFile $paths.Config
$liveModel = Get-ConfigModel $cfgText
if ($current -and $current -ne $provider.id -and $liveModel) {
    Save-ProviderModel -Paths $paths -Id $current -Model $liveModel
}
# 切走之前，把账号 tokens 也备份好
if ($current -eq 'account') { Save-AccountAuth $paths | Out-Null }

$extraKeys = Get-ExtraKeys $paths
$newCfg    = Set-ProviderConfig -Text $cfgText -Provider $provider -ExtraKeys $extraKeys

# 已经在目标站点上时，保留用户此刻选的模型，不覆盖
if ($current -ne $provider.id) {
    $newCfg = Set-ModelKeys -Text $newCfg -Model $model
} elseif ($liveModel) {
    $model = $liveModel
}

Write-TextFile $paths.Config $newCfg

if ($provider.kind -eq 'relay') {
    Set-ApiKeyAuth $paths $key
} else {
    if (-not (Restore-AccountAuth $paths) -and -not $needLogin) { $needLogin = $true }
}

$prevProxy = Get-ProxyState $paths
Update-Proxy -Paths $paths -NewProxy ([string]$provider.proxy) | Out-Null
Set-CurrentMode $paths $provider.id

# ============================================================
# 第四步：结果
# ============================================================
Write-Ok ''
Write-Ok ('已切换到「' + $provider.name + '」')
if ($provider.base_url) { Write-Info ('  接口: ' + $provider.base_url) }
if ($model)             { Write-Info ('  模型: ' + $model) }
if ($provider.proxy)    { Write-Info ('  代理: ' + $provider.proxy) }
elseif ($prevProxy)     { Write-Info '  代理: 已清除' }

# ============================================================
# 第五步：需要时拉起登录，然后打开 Codex
# ============================================================
if ($provider.kind -eq 'account' -and $needLogin) {
    Write-Warn ''
    Write-Warn '没有保存的账号凭据，需要登录一次。'
    Write-Dim  '浏览器会自动打开，把控制台里的验证码填进去即可。'
    Start-CodexLogin | Out-Null
}

if (-not $NoLaunch) {
    Write-Dim ''
    Write-Dim '正在打开 Codex…'
    if (-not (Start-CodexApp)) {
        Write-Warn '没找到 codex.exe，请手动打开 Codex。'
    }
}

exit 0
