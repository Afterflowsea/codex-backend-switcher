<#
  Network.ps1
  和站点做最小化对话，用于"切换前先验证"。

  设计原则：宁可切换失败，也不要把坏配置写进 config.toml。
  很多问题（key 无效、key 所属分组没有该模型、代理没开）都能在这一步暴露，
  并且能把厂商的原始报错原样打给用户——比自己猜"连不上"准确得多。
#>

# 拉模型列表：先试 {base}/models，再试 {base}/v1/models
# （不同中转的路径习惯不一样，有的 base_url 自带 /v1，有的没有）
function Get-ModelList {
    param([string]$BaseUrl, [string]$Key, [string]$ProxyUrl)

    $b = $BaseUrl.TrimEnd('/')
    $lastErr = ''

    foreach ($uri in @(($b + '/models'), ($b + '/v1/models'))) {
        $params = @{
            Uri         = $uri
            Headers     = @{ Authorization = "Bearer $Key" }
            TimeoutSec  = 25
            ErrorAction = 'Stop'
        }
        if ($ProxyUrl) { $params.Proxy = $ProxyUrl }

        try {
            $r = Invoke-RestMethod @params
            $ids = if ($r.data) { @($r.data | ForEach-Object { $_.id }) } else { @() }
            return [pscustomobject]@{ ok = $true; models = $ids; error = ''; endpoint = $uri }
        } catch {
            $lastErr = Get-HttpErrorText $_
        }
    }
    return [pscustomobject]@{ ok = $false; models = @(); error = $lastErr; endpoint = '' }
}

# 真正发一次最小 /responses 请求，确认这个模型能不能对话
function Test-TextModel {
    param([string]$BaseUrl, [string]$Key, [string]$Model, [string]$ProxyUrl)

    $b = $BaseUrl.TrimEnd('/')
    $body = '{"model":"' + $Model + '","input":"hi","max_output_tokens":8}'

    foreach ($uri in @(($b + '/responses'), ($b + '/v1/responses'))) {
        $params = @{
            Uri         = $uri
            Method      = 'Post'
            Headers     = @{ Authorization = "Bearer $Key" }
            ContentType = 'application/json'
            Body        = $body
            TimeoutSec  = 40
            ErrorAction = 'Stop'
        }
        if ($ProxyUrl) { $params.Proxy = $ProxyUrl }

        try {
            Invoke-RestMethod @params | Out-Null
            return [pscustomobject]@{ ok = $true; message = ''; endpoint = $uri }
        } catch {
            return [pscustomobject]@{ ok = $false; message = (Get-HttpErrorText $_); endpoint = $uri }
        }
    }
    return [pscustomobject]@{ ok = $false; message = '请求失败'; endpoint = '' }
}

# 从 Invoke-RestMethod 的异常里挖出服务端返回的 JSON 错误消息
function Get-HttpErrorText {
    param($ErrorRecord)

    $msg = $ErrorRecord.Exception.Message
    $raw = ''
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        $raw = $ErrorRecord.ErrorDetails.Message
    }
    if ($raw) {
        try {
            $j = $raw | ConvertFrom-Json
            if ($j.error.message) { return [string]$j.error.message }
            if ($j.message)       { return [string]$j.message }
            return $raw
        } catch {
            return $raw
        }
    }
    return $msg
}

# 只有图像/视频/向量类模型
function Get-TextModels {
    param($Models)

    # auto-review 是给代码审查用的模型，不能拿来当对话模型
    $pattern = '(?i)(image|sora|dall|flux|midjourney|imagen|video|tts|whisper|embed|sd-|stable-diffusion|auto-review)'
    return @($Models | Where-Object { $_ -notmatch $pattern })
}

<#
  从可用模型里挑一个合理的默认值。
  优先级：站点记忆的模型 > 名字带 codex > 已知强模型 > gpt-6 > gpt-5 > 第一个
#>
function Select-BestModel {
    param($Models, [string]$Preferred)

    if (-not $Models -or $Models.Count -eq 0) { return '' }
    if ($Preferred -and ($Models -contains $Preferred)) { return $Preferred }

    $m = $Models | Where-Object { $_ -match '(?i)codex' } | Select-Object -First 1
    if ($m) { return $m }

    foreach ($w in @('gpt-6-luna', 'gpt-6-sol', 'gpt-6', 'gpt-5.6-luna', 'gpt-5.6-sol')) {
        if ($Models -contains $w) { return $w }
    }
    $m = $Models | Where-Object { $_ -match '^gpt-6' } | Select-Object -First 1
    if ($m) { return $m }
    $m = $Models | Where-Object { $_ -match '^gpt-5' } | Select-Object -First 1
    if ($m) { return $m }
    return $Models[0]
}
