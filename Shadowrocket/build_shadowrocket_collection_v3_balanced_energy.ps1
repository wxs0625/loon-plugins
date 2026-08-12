param(
    [string]$SourceModule = (Join-Path $PSScriptRoot 'v3_Energy_Saving_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'v3_Balanced_Energy_Loon_All_In_One_Fixed_Shadowrocket.sgmodule')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceModule -PathType Leaf)) {
    throw "Source module not found: $SourceModule"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
$lines = [System.IO.File]::ReadAllLines($SourceModule, [System.Text.Encoding]::UTF8)
$output = [System.Collections.Generic.List[string]]::new()
$section = ''
$removedScripts = [System.Collections.Generic.List[string]]::new()
$removedBodyRewrites = [System.Collections.Generic.List[string]]::new()

$scriptTokens = @(
    'groups\/allgroups\/v2',
    'client\/light_skin',
    'littleskin\/preview',
    'appicon\/list',
    'newredirectconfirmcgi',
    'api\.zhihu\.com\/root\/tab',
    'dragon\/ball',
    'common_switch',
    'bottom_theme|home_top_menu',
    'mobile\/config',
    'channel\/index',
    'lantern\.appconfig\.get',
    'interaction\/comment\/video\/download'
)

$bodyRewriteTokens = @(
    'app\.bilibili\.com\/x\/v2\/account\/myinfo',
    'app\.bilibili\.com\/x\/resource\/show\/tab\/v2',
    'api\.zhihu\.com\/root\/tab',
    'api\.zhihu\.com\/search\/tabs',
    'iface2\.iqiyi\.com\/views_menus\/3\.0\/bottom_theme'
)

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $output.Add($line)
        continue
    }
    if ($line -like '#!name=*') {
        $output.Add('#!name=All In One Fixed - Shadowrocket v3 Balanced Energy')
        continue
    }
    if ($line -like '#!desc=*') {
        $output.Add('#!desc=Balanced v3: full ad blocking with selected non-ad enhancements disabled')
        continue
    }
    if ($line -like '#!date=*') {
        $output.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        continue
    }

    $remove = $false
    if ($section -eq 'Script') {
        foreach ($token in $scriptTokens) {
            if ($trimmed.Contains($token)) {
                $remove = $true
                $removedScripts.Add($trimmed)
                break
            }
        }
    } elseif ($section -eq 'Body Rewrite') {
        foreach ($token in $bodyRewriteTokens) {
            if ($trimmed.Contains($token)) {
                $remove = $true
                $removedBodyRewrites.Add($trimmed)
                break
            }
        }
    }

    if (-not $remove) {
        $output.Add($line)
    }
}

if ($removedScripts.Count -eq 0) {
    throw 'No selected non-ad scripts were found.'
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputFile, $output, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    Remove-Item -LiteralPath $OutputFile -Force
    throw 'The conservative energy-saving source changed during the build.'
}

Write-Output "Created: $OutputFile"
Write-Output "Source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash)"
Write-Output "Removed non-ad scripts: $($removedScripts.Count)"
Write-Output "Removed non-ad body rewrites: $($removedBodyRewrites.Count)"