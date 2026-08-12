$ErrorActionPreference = 'Stop'

function ConvertFrom-Utf8Base64 {
    param([string]$Value)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$sourceName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuNi5zZ21vZHVsZQ=='
$outputName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuOS5zZ21vZHVsZQ=='
$displayName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIIDMuOQ=='
$description = ConvertFrom-Utf8Base64 '5Z+65LqOIDMuNiDph43mnoTvvJrmlL7ooYzlv6vmiYsvMVJUQiDliJ3lp4vljJblubbliKDpmaTlhajpg6jlv6vmiYvmi6bmiKrvvIzku4Xmi6bmiKrpl6rliqjmoKHlm63oh6rmnInlub/lkYrmjqXlj6PvvIzkuI3mlrDlop4gTUlUTSDkuLvmnLrvvIzmnIDlpKfpmZDluqbpgb/lhY3pl6rpgIA='
$sourceModule = Join-Path $PSScriptRoot $sourceName
$outputFile = Join-Path $PSScriptRoot $outputName

if (-not (Test-Path -LiteralPath $sourceModule -PathType Leaf)) {
    throw "Source module not found: $sourceModule"
}
if (Test-Path -LiteralPath $outputFile) {
    throw "Output already exists; refusing to overwrite: $outputFile"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $sourceModule -Algorithm SHA256).Hash
$lines = [System.IO.File]::ReadAllLines($sourceModule, [System.Text.Encoding]::UTF8)
$output = [System.Collections.Generic.List[string]]::new()
$section = ''
$removedRules = [System.Collections.Generic.List[string]]::new()
$removedRewrites = [System.Collections.Generic.List[string]]::new()
$removedScripts = [System.Collections.Generic.List[string]]::new()
$addedAdRewrites = 0

$removeRuleLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $removeRuleLines.Add('DOMAIN,open.e.kuaishou.com,REJECT')
$null = $removeRuleLines.Add('DOMAIN-SUFFIX, e.kuaishou.com, REJECT')
$null = $removeRuleLines.Add('DOMAIN-SUFFIX,e.kuaishou.com, REJECT')
$null = $removeRuleLines.Add('DOMAIN-SUFFIX, cm.downloader.commercial.kuaishou.com, REJECT')
$null = $removeRuleLines.Add('DOMAIN-SUFFIX,cm.downloader.commercial.kuaishou.com, REJECT')

$removeRewriteLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $removeRewriteLines.Add('^https:\/\/open\.e\.kuaishou\.cn\/rest\/e\/v3\/open - reject-dict')
$null = $removeRewriteLines.Add('^https:\/\/sdk\.1rtb\.net\/sdk\/req_ad\? - reject-dict')
$null = $removeRewriteLines.Add('^https:\/\/zlsdk\.1rtb\.net\/sdk\/req_ad\?sdk_version=\d+\.\d+\.\d+\.\d+&device_os=iOS&accept_ad_type=\d+&app_id=\d+&pid=\d+&sdk_version_code=\d+ - reject-dict')
$null = $removeRewriteLines.Add('^https?:\/\/zlsdk\.1rtb\.net\/sdk\/req_ad - reject-dict')
$null = $removeRewriteLines.Add('^https?:\/\/open\.e\.kuaishou\.cn\/rest\/e\/v3\/open\/univ - reject')
$null = $removeRewriteLines.Add('^https?:\/\/open\.e\.kuaishou\.com\/rest\/e\/v3\/open\/univ - reject')

$removeScriptPattern = 'open\.e\.kuaishou\.com\/rest\/e\/v3\/open\/univ'

$directRules = @(
    'DOMAIN-SUFFIX,huachenjie.com,DIRECT',
    'DOMAIN,open.e.kuaishou.cn,DIRECT',
    'DOMAIN,open.e.kuaishou.com,DIRECT',
    'DOMAIN,ad.shunchangzhixing.com,DIRECT',
    'DOMAIN-SUFFIX,1rtb.net,DIRECT'
)

$adRewrites = @(
    '^https:\/\/api\.huachenjie\.com\/run-front\/home\/sports\/getPopup(?:\?.*)? - reject-dict',
    '^https:\/\/api\.huachenjie\.com\/run-front\/ad(?:\?.*)? - reject-dict',
    '^http:\/\/ad\.shunchangzhixing\.com\/getAd(?:\?.*)? - reject-dict'
)

$directAdded = 0

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $output.Add($line)
        if ($section -eq 'Rule') {
            foreach ($r in $directRules) { $output.Add($r) }
            $directAdded = $directRules.Count
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
    if ($section -eq 'URL Rewrite' -and $addedAdRewrites -eq 0 -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
        foreach ($adRewrite in $adRewrites) {
            $output.Add($adRewrite)
            $addedAdRewrites++
        }
    }
    if ($section -eq 'Script' -and $trimmed -match [regex]::Escape($removeScriptPattern)) {
        $removedScripts.Add($trimmed)
        continue
    }

    $output.Add($line)
}

if ($directAdded -ne $directRules.Count) {
    throw "Expected $($directRules.Count) DIRECT rules, added $directAdded"
}
if ($removedRules.Count -ne $removeRuleLines.Count) {
    throw "Expected $($removeRuleLines.Count) risky rules, removed $($removedRules.Count)"
}
if ($removedRewrites.Count -ne $removeRewriteLines.Count) {
    throw "Expected $($removeRewriteLines.Count) risky rewrites, removed $($removedRewrites.Count)"
}
if ($removedScripts.Count -ne 1) {
    throw "Expected 1 ad-alliance script with kuaishou pattern, removed $($removedScripts.Count)"
}
if ($addedAdRewrites -ne $adRewrites.Count) {
    throw "Expected $($adRewrites.Count) splash ad rewrites, added $addedAdRewrites"
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($outputFile, $output, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $sourceModule -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    Remove-Item -LiteralPath $outputFile -Force
    throw 'Source module changed during build.'
}

Write-Output "Created: $outputFile"
Write-Output "Source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash)"
Write-Output "Added DIRECT rules: $directAdded"
Write-Output "Removed risky domain rules: $($removedRules.Count)"
Write-Output "Removed risky rewrites: $($removedRewrites.Count)"
Write-Output "Removed ad-alliance scripts: $($removedScripts.Count)"
Write-Output "Added splash ad rewrites: $addedAdRewrites"
