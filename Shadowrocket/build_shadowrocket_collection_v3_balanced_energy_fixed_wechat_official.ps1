param(
    [string]$SourceModule = (Join-Path $PSScriptRoot 'v3_Balanced_Energy_Fixed_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'v3_Balanced_Energy_Fixed_WeChat_Official_Loon_All_In_One_Fixed_Shadowrocket.sgmodule')
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
$replacementCount = 0

$conflictingRule = '^https:\/\/mp\.weixin\.qq\.com\/mp\/(cps_product_info|getappmsgad|jsmonitor|masonryfeed|relatedarticle)\? - reject-dict'
$fixedRule = '^https:\/\/mp\.weixin\.qq\.com\/mp\/(cps_product_info|jsmonitor|masonryfeed|relatedarticle)\? - reject-dict'

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $output.Add($line)
        continue
    }
    if ($line -like '#!name=*') {
        $output.Add('#!name=All In One Fixed - Shadowrocket v3 Balanced Energy Fixed WeChat Official')
        continue
    }
    if ($line -like '#!desc=*') {
        $output.Add('#!desc=Balanced energy fixed with WeChat Official Account ad response repair')
        continue
    }
    if ($line -like '#!date=*') {
        $output.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        continue
    }

    if ($section -eq 'URL Rewrite' -and $trimmed -eq $conflictingRule) {
        $output.Add($fixedRule)
        $replacementCount++
        continue
    }

    $output.Add($line)
}

if ($replacementCount -ne 1) {
    throw "Unexpected conflicting WeChat rule count: $replacementCount"
}

$bodyRewrite = 'http-response ^https?:\/\/mp\.weixin\.qq\.com\/mp\/getappmsgad advertisement fmz200'
if (($output | Where-Object { $_.Trim() -eq $bodyRewrite }).Count -ne 1) {
    throw 'Expected exactly one WeChat getappmsgad body rewrite.'
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
    throw 'The balanced energy fixed source changed during the build.'
}

Write-Output "Created: $OutputFile"
Write-Output "Source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash)"
Write-Output "Repaired conflicting WeChat rules: $replacementCount"