$ErrorActionPreference = 'Stop'

function ConvertFrom-Utf8Base64 {
    param([string]$Value)

    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$sourceName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuNi5zZ21vZHVsZQ=='
$outputName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuNy5zZ21vZHVsZQ=='
$displayName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIIDMuNw=='
$description = ConvertFrom-Utf8Base64 'My42IOeahOesrOS4g+S4quWwj+eJiOacrA=='
$SourceModule = Join-Path $PSScriptRoot $sourceName
$OutputFile = Join-Path $PSScriptRoot $outputName

if (-not (Test-Path -LiteralPath $SourceModule -PathType Leaf)) {
    throw "Source module not found: $SourceModule"
}
if (Test-Path -LiteralPath $OutputFile) {
    throw "Output already exists; refusing to overwrite: $OutputFile"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
$lines = [System.IO.File]::ReadAllLines($SourceModule, [System.Text.Encoding]::UTF8)
$output = [System.Collections.Generic.List[string]]::new()
$section = ''
$removedRules = [System.Collections.Generic.List[string]]::new()
$removedRewrites = [System.Collections.Generic.List[string]]::new()
$removedScripts = [System.Collections.Generic.List[string]]::new()
$addedRuleLines = 0

$removeRuleLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $removeRuleLines.Add('DOMAIN,open.e.kuaishou.com,REJECT')
$null = $removeRuleLines.Add('DOMAIN-SUFFIX, e.kuaishou.com, REJECT')
$null = $removeRuleLines.Add('DOMAIN-SUFFIX,e.kuaishou.com, REJECT')

$removeRewriteLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $removeRewriteLines.Add('^https?:\/\/open\.e\.kuaishou\.cn\/rest\/e\/v3\/open\/univ - reject')
$null = $removeRewriteLines.Add('^https?:\/\/open\.e\.kuaishou\.com\/rest\/e\/v3\/open\/univ - reject')

$directRules = @(
    'DOMAIN-SUFFIX,huachenjie.com,DIRECT',
    'DOMAIN,open.e.kuaishou.cn,DIRECT',
    'DOMAIN,open.e.kuaishou.com,DIRECT',
    'DOMAIN,ad.shunchangzhixing.com,DIRECT',
    'DOMAIN-SUFFIX,1rtb.net,DIRECT'
)

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $output.Add($line)
        if ($section -eq 'Rule') {
            foreach ($directRule in $directRules) {
                $output.Add($directRule)
                $addedRuleLines++
            }
        }
        continue
    }
    if ($line -like '#!name=*') {
        $output.Add('#!name=' + $displayName)
        continue
    }
    if ($line -like '#!desc=*') {
        $output.Add('#!desc=' + $description)
        continue
    }
    if ($line -like '#!date=*') {
        $output.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        continue
    }

    if ($section -eq 'Rule' -and $removeRuleLines.Contains($trimmed)) {
        $removedRules.Add($trimmed)
        continue
    }
    if ($section -eq 'URL Rewrite' -and $removeRewriteLines.Contains($trimmed)) {
        $removedRewrites.Add($trimmed)
        continue
    }
    if ($section -eq 'Script' -and $trimmed -match 'open\\\.e\\\.kuaishou\\\.com\\/rest\\/e\\/v3\\/open\\/univ') {
        $removedScripts.Add($trimmed)
        continue
    }

    $output.Add($line)
}

if ($addedRuleLines -ne $directRules.Count) {
    throw "Expected $($directRules.Count) direct rules, added $addedRuleLines"
}
if ($removedRules.Count -ne 3) {
    throw "Expected 3 conflicting domain rules, removed $($removedRules.Count)"
}
if ($removedRewrites.Count -ne 2) {
    throw "Expected 2 hard reject rewrites, removed $($removedRewrites.Count)"
}
if ($removedScripts.Count -ne 1) {
    throw "Expected 1 conflicting Kuaishou response script, removed $($removedScripts.Count)"
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputFile, $output, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    Remove-Item -LiteralPath $OutputFile -Force
    throw 'Source module changed during build.'
}

Write-Output "Created: $OutputFile"
Write-Output "Source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash)"
Write-Output "Removed conflicting domain rules: $($removedRules.Count)"
Write-Output "Removed hard reject rewrites: $($removedRewrites.Count)"
Write-Output "Removed conflicting scripts: $($removedScripts.Count)"
Write-Output "Added direct rules: $addedRuleLines"