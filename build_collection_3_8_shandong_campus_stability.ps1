$ErrorActionPreference = 'Stop'

function ConvertFrom-Utf8Base64 {
    param([string]$Value)

    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$sourceName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuNy5zZ21vZHVsZQ=='
$outputName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIXzMuOC5zZ21vZHVsZQ=='
$displayName = ConvertFrom-Utf8Base64 '6ZuG5ZCI5L+u5aSN54mIIDMuOA=='
$description = ConvertFrom-Utf8Base64 '56iz5a6a5LyY5YWI77ya5pS+6KGM5b+r5omL5LiOIDFSVEIg5Yid5aeL5YyW77yM5LuF5aSE55CG6Zeq5Yqo5qCh5Zut5piO56Gu5bm/5ZGK5o6l5Y+j'
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
$addedAdRewrites = 0
$mitmUpdated = 0

$removeRewriteLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $removeRewriteLines.Add('^https:\/\/open\.e\.kuaishou\.cn\/rest\/e\/v3\/open - reject-dict')
$null = $removeRewriteLines.Add('^https:\/\/sdk\.1rtb\.net\/sdk\/req_ad\? - reject-dict')
$null = $removeRewriteLines.Add('^https:\/\/zlsdk\.1rtb\.net\/sdk\/req_ad\?sdk_version=\d+\.\d+\.\d+\.\d+&device_os=iOS&accept_ad_type=\d+&app_id=\d+&pid=\d+&sdk_version_code=\d+ - reject-dict')
$null = $removeRewriteLines.Add('^https?:\/\/zlsdk\.1rtb\.net\/sdk\/req_ad - reject-dict')

$adRewrites = @(
    '^https:\/\/api\.huachenjie\.com\/run-front\/home\/sports\/getPopup(?:\?.*)? - reject-dict',
    '^https:\/\/api\.huachenjie\.com\/run-front\/ad(?:\?.*)? - reject-dict',
    '^http:\/\/ad\.shunchangzhixing\.com\/getAd(?:\?.*)? - reject-dict'
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
    if ($section -eq 'URL Rewrite' -and $addedAdRewrites -eq 0 -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
        foreach ($adRewrite in $adRewrites) {
            $output.Add($adRewrite)
            $addedAdRewrites++
        }
    }
    if ($section -eq 'MITM' -and $trimmed -like 'hostname =*') {
        if ($trimmed -match '(^|,\s*)api\.huachenjie\.com(,|$)') {
            throw 'MITM hostname already contains api.huachenjie.com'
        }
        $output.Add($line + ', api.huachenjie.com')
        $mitmUpdated++
        continue
    }

    $output.Add($line)
}

if ($removedRewrites.Count -ne $removeRewriteLines.Count) {
    throw "Expected $($removeRewriteLines.Count) risky rewrites, removed $($removedRewrites.Count)"
}
if ($addedAdRewrites -ne $adRewrites.Count) {
    throw "Expected $($adRewrites.Count) splash ad rewrites, added $addedAdRewrites"
}
if ($mitmUpdated -ne 1) {
    throw "Expected one MITM hostname line, updated $mitmUpdated"
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
Write-Output "Removed risky rewrites: $($removedRewrites.Count)"
Write-Output "Added splash ad rewrites: $addedAdRewrites"
Write-Output "Updated MITM hostname lines: $mitmUpdated"