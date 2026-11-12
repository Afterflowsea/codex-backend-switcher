<#
  syntax-check.ps1
  语法检查：所有 .ps1 文件必须能被 PowerShell 解析。

  为什么单独成文件而不是写在 workflow 的 run: 里：
  GitHub Actions 把内联脚本写成 UTF-8 无 BOM 的临时 .ps1，
  PowerShell 5.1 会按 ANSI 解码，中文变成乱码后连引号都会被吃掉，
  导致"0 秒就失败"且看不出原因。放进仓库文件（带 BOM）就没这问题。
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$failed = 0
$count = 0

foreach ($f in (Get-ChildItem -Path $repoRoot -Recurse -Filter *.ps1)) {
    $count++
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        Write-Host ('语法错误: ' + $f.FullName) -ForegroundColor Red
        foreach ($e in $errors) { Write-Host ('  ' + $e.Message) }
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host ('共 ' + $count + ' 个文件，' + $failed + ' 个解析失败') -ForegroundColor Red
    exit 1
}

Write-Host ('全部 ' + $count + ' 个 .ps1 解析通过') -ForegroundColor Green
exit 0
