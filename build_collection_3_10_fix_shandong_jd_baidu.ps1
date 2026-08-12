$ErrorActionPreference = 'Stop'

function ConvertFrom-Utf8Base64 {
    param([string]$Value)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$sourceName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuOS5zZ21vZHVsZQ=='
$outputName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuMTAuc2dtb2R1bGU='
$displayName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIIDMuMTA='
$description = ConvertFrom-Utf8Base64 '5L2/55SoIDMuMTDvvJrnp7vpmaTpl6rliqjmoKHlm63lub/lkYogU0RLIHJlamVjdC1kaWN0IOW0qea6g+inhOWIme+8jOaWsOWinuS6rOS4nOW8gOWxj+W5v+WRiuWxj+iUveinhOWImeOAgueZvuW6pue9keebmOinhOWImeWcqCAzLjYg5bey5pyJ77yM5peg6ZyA6YeN5aSN5re75Yqg44CC'
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
    '^https?:\/\/img\d+\.360buyimg\.com\/jddjadvertise\/ - reject'
)

$baiduAdRewrites = @()

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
        if ($jdAdRewrites.Count -gt 0) {
            $output.Add('# === 京东开屏广告增强 ===')
            foreach ($r in $jdAdRewrites) {
                $output.Add($r)
                $addedJdRewrites++
            }
        }
        if ($baiduAdRewrites.Count -gt 0) {
            $output.Add('# === 百度网盘开屏广告增强 ===')
            foreach ($r in $baiduAdRewrites) {
                $output.Add($r)
                $addedBaiduRewrites++
            }
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
