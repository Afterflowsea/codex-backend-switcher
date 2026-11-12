<#
  CodexConfig.ps1
  对 ~/.codex/config.toml 做"外科手术"：只增删和中转相关的几行，
  其它内容（项目信任、主题、MCP、插件…）原样保留。

  需要注意的 TOML 规则：根级键必须写在任何 [table] 之前，
  所以 model_provider / model / web_search 这类键插在文件最前面，
  而 [model_providers.xxx] 表追加在文件末尾。
#>

<#
  删掉所有中转相关内容：
    - 根级 model_provider = "xxx"
    - 整个 [model_providers.*] 表（到下一个 table 头为止）
    - 由站点 extra 引入的根级键（如 web_search）
#>
function Remove-ProviderBlock {
    param([string]$Text, [string[]]$ExtraKeys = @())

    $out  = New-Object System.Collections.Generic.List[string]
    $skip = $false

    foreach ($line in ($Text -split "`r?`n")) {
        # 进入 model_providers 表：整块跳过
        if ($line -match '^\s*\[\s*model_providers\s*\.') { $skip = $true; continue }

        if ($skip) {
            # 遇到下一个 table 头，结束跳过并保留这一行
            if ($line -match '^\s*\[') { $skip = $false } else { continue }
        }

        if ($line -match '^\s*model_provider\s*=') { continue }

        $hit = $false
        foreach ($k in $ExtraKeys) {
            if ($line -match ('^\s*' + [regex]::Escape($k) + '\s*=')) { $hit = $true; break }
        }
        if ($hit) { continue }

        $out.Add($line)
    }
    return ($out -join "`r`n")
}

# 写入中转 provider 表（追加到文件末尾，合法且不会破坏根级键）
function Add-ProviderBlock {
    param([string]$Text, $Provider)

    $t  = 'model_provider = "' + $Provider.id + '"' + "`r`n" + $Text.TrimEnd()
    $t += "`r`n`r`n[model_providers." + $Provider.id + "]`r`n"
    $t += 'name = "'   + $Provider.name     + '"' + "`r`n"
    $t += 'base_url = "' + $Provider.base_url + '"' + "`r`n"
    $t += 'wire_api = "responses"' + "`r`n"
    $t += 'requires_openai_auth = true' + "`r`n"
    return $t
}

# 站点自定义的附加根级键（字符串加引号，数字/布尔原样）
function Add-ExtraKeys {
    param([string]$Text, $Provider)

    if (-not $Provider.extra) { return $Text }

    $lines = @()
    foreach ($pr in $Provider.extra.PSObject.Properties) {
        if ($pr.Value -is [string]) { $lines += ($pr.Name + ' = "' + $pr.Value + '"') }
        else                        { $lines += ($pr.Name + ' = '  + $pr.Value) }
    }
    if ($lines.Count -eq 0) { return $Text }
    return (($lines -join "`r`n") + "`r`n" + $Text)
}

# 替换或插入一个字符串型根级键
function Set-RootStringKey {
    param([string]$Text, [string]$Name, [string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $Text }

    $re = New-Object System.Text.RegularExpressions.Regex('(?m)^' + [regex]::Escape($Name) + '\s*=\s*"[^"]*"[ \t]*\r?$')
    if ($re.IsMatch($Text)) {
        return $re.Replace($Text, ($Name + ' = "' + $Value + '"'), 1)
    }
    return ($Name + ' = "' + $Value + '"' + "`r`n" + $Text)
}

# 同时设置 model 和 review_model，避免切站后 review 还指向上一个站不存在的模型
function Set-ModelKeys {
    param([string]$Text, [string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) { return $Text }
    $Text = Set-RootStringKey $Text 'model'        $Model
    $Text = Set-RootStringKey $Text 'review_model' $Model
    return $Text
}

# 从 config.toml 里读出当前 model
function Get-ConfigModel {
    param([string]$Text)

    $m = [regex]::Match($Text, '(?m)^model\s*=\s*"([^"]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

<#
  完整应用一次站点配置：
    1. 清掉旧的中转痕迹
    2. relay 站点追加 provider 表和附加键
    3. 设置模型
#>
function Set-ProviderConfig {
    param([string]$Text, $Provider, [string[]]$ExtraKeys = @())

    $t = Remove-ProviderBlock -Text $Text -ExtraKeys $ExtraKeys
    if ($Provider.kind -eq 'relay') {
        $t = Add-ProviderBlock -Text $t -Provider $Provider
        $t = Add-ExtraKeys     -Text $t -Provider $Provider
    }
    $t = Set-ModelKeys -Text $t -Model $Provider.model
    return $t
}
