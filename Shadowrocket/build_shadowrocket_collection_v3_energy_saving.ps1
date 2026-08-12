param(
    [string]$SourceModule = (Join-Path $PSScriptRoot 'v3_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'v3_Energy_Saving_Loon_All_In_One_Fixed_Shadowrocket.sgmodule')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceModule -PathType Leaf)) {
    throw "Source module not found: $SourceModule"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
$sourceLines = [System.IO.File]::ReadAllLines($SourceModule, [System.Text.Encoding]::UTF8)
$outputLines = [System.Collections.Generic.List[string]]::new()
$section = ''
$mitmFound = $false
$originalHostCount = 0
$optimizedHostCount = 0

foreach ($line in $sourceLines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $outputLines.Add($line)
        continue
    }
    if ($line -like '#!name=*') {
        $outputLines.Add('#!name=All In One Fixed - Shadowrocket v3 Energy Saving')
        continue
    }
    if ($line -like '#!desc=*') {
        $outputLines.Add('#!desc=Full-featured v3 with conservative MITM deduplication for lower overhead')
        continue
    }
    if ($line -like '#!date=*') {
        $outputLines.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        continue
    }
    if ($section -ne 'MITM' -or $trimmed -notmatch '^hostname\s*=') {
        $outputLines.Add($line)
        continue
    }

    $mitmFound = $true
    $rawHostText = ($trimmed -split '=', 2)[1] -replace '^\s*%APPEND%\s*', ''
    $hostnames = [System.Collections.Generic.List[string]]::new()
    foreach ($rawHostname in ($rawHostText -split ',')) {
        $hostname = $rawHostname.Trim()
        if (-not $hostname) {
            continue
        }
        if ($hostname -eq 'cupid.51job*.comhostname = img01.51jobcdn.com') {
            $hostnames.Add('cupid.51job*.com')
            $hostnames.Add('img01.51jobcdn.com')
            continue
        }
        if ($hostname -eq 'res1.hubcloud.com.cnhostname = api.xiachufang.com') {
            $hostnames.Add('res1.hubcloud.com.cn')
            $hostnames.Add('api.xiachufang.com')
            continue
        }
        $hostnames.Add($hostname)
    }

    $originalHostCount = ($rawHostText -split ',' | Where-Object { $_.Trim() }).Count
    $hostSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($hostname in $hostnames) {
        [void]$hostSet.Add($hostname)
    }

    $redundantHostnames = [System.Collections.Generic.List[string]]::new()
    foreach ($hostname in $hostSet) {
        if ($hostname -match '[*?]') {
            continue
        }
        $labels = $hostname -split '\.'
        if ($labels.Count -lt 3) {
            continue
        }
        $parentWildcard = '*.' + ($labels[1..($labels.Count - 1)] -join '.')
        if ($hostSet.Contains($parentWildcard)) {
            $redundantHostnames.Add($hostname)
        }
    }
    foreach ($hostname in $redundantHostnames) {
        [void]$hostSet.Remove($hostname)
    }

    $optimizedHostCount = $hostSet.Count
    $outputLines.Add('hostname = %APPEND% ' + (($hostSet | Sort-Object) -join ', '))
}

if (-not $mitmFound) {
    throw 'MITM hostname line was not found.'
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputFile, $outputLines, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    Remove-Item -LiteralPath $OutputFile -Force
    throw 'The v3 source module changed during the build.'
}

Write-Output "Created: $OutputFile"
Write-Output "v3 source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash)"
Write-Output "MITM hostnames: $originalHostCount -> $optimizedHostCount"