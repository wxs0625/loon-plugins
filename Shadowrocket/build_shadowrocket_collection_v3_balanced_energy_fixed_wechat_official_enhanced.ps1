param(
    [string]$SourceModule = (Join-Path $PSScriptRoot 'v3_Balanced_Energy_Fixed_WeChat_Official_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'v3_Balanced_Energy_Fixed_WeChat_Official_Enhanced_Loon_All_In_One_Fixed_Shadowrocket.sgmodule')
)

$ErrorActionPreference = 'Stop'

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
$removedBodyRewriteCount = 0
$addedScriptCount = 0

$oldBodyRewrite = 'http-response ^https?:\/\/mp\.weixin\.qq\.com\/mp\/getappmsgad advertisement fmz200'
$scriptLine = 'WeChat Official Account Ads = type=http-response, pattern=^https?:\/\/mp\.weixin\.qq\.com\/mp\/getappmsgad, script-path=https://raw.githubusercontent.com/wxs0625/loon-plugins/main/Shadowrocket/wechat_official_remove_ads.js, requires-body=true, timeout=10'

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $output.Add($line)
        continue
    }
    if ($line -like '#!name=*') {
        $output.Add('#!name=All In One Fixed - Shadowrocket v3 Balanced Energy Fixed WeChat Official Enhanced')
        continue
    }
    if ($line -like '#!desc=*') {
        $output.Add('#!desc=Structured WeChat Official Account ad cleanup to remove ad placeholders')
        continue
    }
    if ($line -like '#!date=*') {
        $output.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        continue
    }

    if ($section -eq 'Body Rewrite' -and $trimmed -eq $oldBodyRewrite) {
        $removedBodyRewriteCount++
        continue
    }

    if ($section -eq 'Script' -and $addedScriptCount -eq 0 -and $trimmed -and -not $trimmed.StartsWith('#')) {
        $output.Add($scriptLine)
        $addedScriptCount++
    }

    $output.Add($line)
}

if ($removedBodyRewriteCount -ne 1 -or $addedScriptCount -ne 1) {
    throw "Unexpected change count: removed body rewrites=$removedBodyRewriteCount, added scripts=$addedScriptCount"
}
if (($output | Where-Object { $_.Trim() -eq $scriptLine }).Count -ne 1) {
    throw 'Expected exactly one structured WeChat cleanup script.'
}

$mitmText = ($output | Where-Object { $_ -like 'hostname =*' }) -join ','
if ($mitmText -notmatch '(^|[ ,])mp\.weixin\.qq\.com([, ]|$)') {
    throw 'Required WeChat MITM hostname is missing.'
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputFile, $output, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    Remove-Item -LiteralPath $OutputFile -Force
    throw 'The WeChat Official Account source changed during the build.'
}

Write-Output "Created: $OutputFile"
Write-Output "Source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash)"
Write-Output "Removed legacy body rewrites: $removedBodyRewriteCount"
Write-Output "Added structured scripts: $addedScriptCount"