$ErrorActionPreference = 'Stop'

function ConvertFrom-Utf8Base64 {
    param([string]$Value)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$sourceName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuOS5zZ21vZHVsZQ=='
$outputName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuMTAuc2dtb2R1bGU='
$displayName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIIDMuMTA='
$description = ConvertFrom-Utf8Base64 '5Z+65LqOIDMuOSDkv67lpI3vvJrnp7vpmaTpl6rliqjmoKHlm63lub/lkYrph43lhpnpgb/lhY0gU0RLIOaUtuepuuWvueixoemXqumAgO+8jOWinuW8uuS6rOS4nOWSjOeZvuW6pue9keebmOW8gOWxj+W5v+WRiuaLpuaIqg=='
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
$removedRewrites = [System.Collections.Generic.List[string]]::new()
$addedJdRewrites = 0
$addedBaiduRewrites = 0
$adRewritesInserted = $false

$removeRewriteLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $removeRewriteLines.Add('^https:\/\/api\.huachenjie\.com\/run-front\/home\/sports\/getPopup(?:\?.*)? - reject-dict')
$null = $removeRewriteLines.Add('^https:\/\/api\.huachenjie\.com\/run-front\/ad(?:\?.*)? - reject-dict')
$null = $removeRewriteLines.Add('^http:\/\/ad\.shunchangzhixing\.com\/getAd(?:\?.*)? - reject-dict')

$jdAdRewrites = @(
    '^https?:\/\/api\.m\.jd\.com\/client\.action\?functionId=queryMaterialAdverts - reject',
    '^https?:\/\/(bdsp-x|dsp-x)\.jd\.com\/adx\/sdk\/open - reject',
    '^https?:\/\/img\d+\.360buyimg\.com\/jddjadvertise\/ - reject'
)

$baiduAdRewrites = @(
    '^https?:\/\/issuecdn\.baidupcs\.com\/issue\/netdisk\/guanggao\/ - reject',
    '^https?:\/\/staticsns\.cdn\.bcebos\.com\/amis\/.+\/banner\.png - reject',
    '^https?:\/\/d3g6o6c6r6f4\.cdn\.bcebos\.com\/.+\.mp4 - reject'
)

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $output.Add($line)
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

    if ($section -eq 'URL Rewrite' -and $removeRewriteLines.Contains($trimmed)) {
        $removedRewrites.Add($trimmed)
        continue
    }

    if ($section -eq 'URL Rewrite' -and -not $adRewritesInserted -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
        $output.Add('# === 京东开屏广告增强 ===')
        foreach ($r in $jdAdRewrites) {
            $output.Add($r)
            $addedJdRewrites++
        }
        $output.Add('# === 百度网盘开屏广告增强 ===')
        foreach ($r in $baiduAdRewrites) {
            $output.Add($r)
            $addedBaiduRewrites++
        }
        $adRewritesInserted = $true
    }

    $output.Add($line)
}

if ($removedRewrites.Count -ne $removeRewriteLines.Count) {
    throw "Expected $($removeRewriteLines.Count) shandong rewrites removed, got $($removedRewrites.Count)"
}
if ($addedJdRewrites -ne $jdAdRewrites.Count) {
    throw "Expected $($jdAdRewrites.Count) JD rewrites added, got $addedJdRewrites"
}
if ($addedBaiduRewrites -ne $baiduAdRewrites.Count) {
    throw "Expected $($baiduAdRewrites.Count) Baidu rewrites added, got $addedBaiduRewrites"
}
if (-not $adRewritesInserted) {
    throw 'Ad rewrite insertion point not found'
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
Write-Output "Removed shandong ad rewrites: $($removedRewrites.Count)"
Write-Output "Added JD ad rewrites: $addedJdRewrites"
Write-Output "Added Baidu ad rewrites: $addedBaiduRewrites"
