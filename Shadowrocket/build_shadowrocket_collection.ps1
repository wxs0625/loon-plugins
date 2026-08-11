param(
    [string]$SourceCollection = 'C:\Users\wxs\Desktop\Loon_All_In_One_Fixed.plugin',
    [string]$ModuleDirectory = (Join-Path $PSScriptRoot 'Modules'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'Loon_All_In_One_Fixed_Shadowrocket.sgmodule')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceCollection -PathType Leaf)) {
    throw "Source collection not found: $SourceCollection"
}
if (-not (Test-Path -LiteralPath $ModuleDirectory -PathType Container)) {
    throw "Module directory not found: $ModuleDirectory"
}

$sectionOrder = @(
    'Rule',
    'URL Rewrite',
    'Body Rewrite',
    'Map Local',
    'Header Rewrite',
    'Script'
)
$content = @{}
$seen = @{}
foreach ($section in $sectionOrder) {
    $content[$section] = [System.Collections.Generic.List[string]]::new()
    $seen[$section] = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
}
$hostnames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$scriptNames = @{}
$unsupported = [System.Collections.Generic.List[string]]::new()
$sourceModules = [System.Collections.Generic.List[string]]::new()
$scriptNumber = 0

function Add-UniqueLine {
    param(
        [string]$Section,
        [string]$Line,
        [string]$Key
    )

    $trimmed = $Line.Trim()
    if (-not $trimmed) {
        return
    }
    if (-not $Key) {
        $Key = $trimmed
    }
    if ($script:seen[$Section].Add($Key.Trim())) {
        $script:content[$Section].Add($trimmed)
    }
}

function Add-Hostnames {
    param([string]$Line)

    $value = $Line -replace '^\s*hostname\s*=\s*', ''
    $value = $value -replace '^%APPEND%\s*', ''
    foreach ($hostname in ($value -split ',')) {
        $trimmed = $hostname.Trim()
        if ($trimmed) {
            [void]$script:hostnames.Add($trimmed)
        }
    }
}

function Get-UniqueScriptName {
    param([string]$Name)

    $baseName = $Name -replace '\s*=\s*', '-'
    if ($script:scriptNames.ContainsKey($baseName)) {
        $script:scriptNames[$baseName]++
        return "$baseName #$($script:scriptNames[$baseName])"
    }
    $script:scriptNames[$baseName] = 1
    return $baseName
}

function Add-ShadowrocketScript {
    param(
        [string]$Line,
        [string]$PreferredName
    )

    $trimmed = $Line.Trim()
    if ($trimmed -match '^(.+?)\s*=\s*(type=http-(?:request|response),\s*.+)$') {
        $name = Get-UniqueScriptName -Name $Matches[1].Trim()
        $definition = $Matches[2]
        Add-UniqueLine -Section 'Script' -Line "$name = $definition" -Key $definition
        return
    }
    if ($trimmed -notmatch '^(http-(?:request|response))\s+(\S+)\s+(.+)$') {
        $script:unsupported.Add("[Script] $trimmed")
        return
    }

    $type = $Matches[1]
    $pattern = $Matches[2]
    $options = $Matches[3]
    $tag = $null
    if ($options -match '(?:^|,\s*)tag\s*=\s*(.+?)(?=,\s*enable\s*=|$)') {
        $tag = $Matches[1].Trim()
    }
    $options = $options -replace ',\s*tag\s*=\s*.+?(?=,\s*enable\s*=|$)', ''
    $options = $options -replace ',\s*enable\s*=\s*\{[^}]+\}', ''
    $options = $options -replace ',\s*argument\s*=\s*\[[^]]*\{[^]]*\]', ''
    $script:scriptNumber++
    $name = if ($tag) { $tag } elseif ($PreferredName) { $PreferredName } else { "MergedScript$($script:scriptNumber.ToString('0000'))" }
    $name = Get-UniqueScriptName -Name $name
    $converted = "$name = type=$type, pattern=$pattern, $options"
    $key = "type=$type, pattern=$pattern, $options"
    Add-UniqueLine -Section 'Script' -Line $converted -Key $key
}

function Convert-OldRewriteLine {
    param([string]$Line)

    $trimmed = $Line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) {
        return
    }
    if ($trimmed -match '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|IP-CIDR6?|URL-REGEX|USER-AGENT|AND),') {
        Add-UniqueLine -Section 'Rule' -Line $trimmed
        return
    }
    if ($trimmed -match '^http-(?:request|response)\s+') {
        Add-ShadowrocketScript -Line $trimmed
        return
    }
    if ($trimmed -match '^(.+?)\s+response-body-json-jq\s+(.+)$') {
        Add-UniqueLine -Section 'Body Rewrite' -Line "http-response-jq $($Matches[1]) $($Matches[2])"
        return
    }
    if ($trimmed -match '^(.+?)\s+response-body-replace-regex\s+(\S+)\s+(.+)$') {
        Add-UniqueLine -Section 'Body Rewrite' -Line "http-response $($Matches[1]) $($Matches[2]) $($Matches[3])"
        return
    }
    if ($trimmed -match '^(.+?)\s+(reject(?:-[A-Za-z0-9_-]+)?)\s*$') {
        Add-UniqueLine -Section 'URL Rewrite' -Line "$($Matches[1]) - $($Matches[2])"
        return
    }
    if ($trimmed -match '^(.+?)\s+((?:https?://|\$)\S+|30[1278])\s*$') {
        Add-UniqueLine -Section 'URL Rewrite' -Line "$($Matches[1]) - $($Matches[2])"
        return
    }
    $script:unsupported.Add("[Rewrite] $trimmed")
}

function Read-SectionedFile {
    param([string]$Path)

    $sections = @{}
    $currentSection = $null
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ($line -match '^\s*\[([^]]+)\]\s*$') {
            $currentSection = $Matches[1]
            if (-not $sections.ContainsKey($currentSection)) {
                $sections[$currentSection] = [System.Collections.Generic.List[string]]::new()
            }
            continue
        }
        if ($currentSection) {
            $sections[$currentSection].Add($line)
        }
    }
    return $sections
}

$oldSections = Read-SectionedFile -Path $SourceCollection
foreach ($line in $oldSections['Rule']) {
    if ($line.Trim() -and -not $line.TrimStart().StartsWith('#')) {
        Add-UniqueLine -Section 'Rule' -Line $line
    }
}
foreach ($line in $oldSections['Rewrite']) {
    Convert-OldRewriteLine -Line $line
}
foreach ($line in $oldSections['Script']) {
    Convert-OldRewriteLine -Line $line
}
foreach ($line in $oldSections['MITM']) {
    if ($line -match '^\s*hostname\s*=') {
        Add-Hostnames -Line $line
    }
}

$moduleFiles = @(Get-ChildItem -LiteralPath $ModuleDirectory -Filter '*.sgmodule' -File | Sort-Object Name)
foreach ($moduleFile in $moduleFiles) {
    $moduleLines = @(Get-Content -LiteralPath $moduleFile.FullName -Encoding UTF8)
    $moduleNameLine = $moduleLines | Where-Object { $_ -match '^#!name\s*=' } | Select-Object -First 1
    $moduleName = if ($moduleNameLine) { ($moduleNameLine -replace '^#!name\s*=\s*', '').Trim() } else { $moduleFile.BaseName }
    $sourceModules.Add($moduleName)
    $moduleSections = Read-SectionedFile -Path $moduleFile.FullName

    foreach ($section in $sectionOrder) {
        if (-not $moduleSections.ContainsKey($section)) {
            continue
        }
        foreach ($line in $moduleSections[$section]) {
            $trimmed = $line.Trim()
            if (-not $trimmed -or $trimmed.StartsWith('#')) {
                continue
            }
            if ($section -eq 'Script') {
                Add-ShadowrocketScript -Line $trimmed -PreferredName $moduleName
            } else {
                Add-UniqueLine -Section $section -Line $trimmed
            }
        }
    }
    if ($moduleSections.ContainsKey('MITM')) {
        foreach ($line in $moduleSections['MITM']) {
            if ($line -match '^\s*hostname\s*=') {
                Add-Hostnames -Line $line
            }
        }
    }
}

$output = [System.Collections.Generic.List[string]]::new()
$output.Add('#!name=All In One Fixed - Shadowrocket')
$output.Add('#!desc=Converted from the wool_scripts Loon collection and merged with 33 local Shadowrocket modules')
$output.Add('#!author=fmz200, local merge')
$output.Add('#!homepage=https://github.com/fmz200/wool_scripts')
$output.Add('#!icon=https://raw.githubusercontent.com/fmz200/wool_scripts/main/icons/gif/naisi-01.gif')
$output.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$output.Add('')
$output.Add('# Integrated local modules: ' + ($sourceModules -join ', '))
$output.Add('# Advanced Loon directives not safely convertible: ' + $unsupported.Count)
$output.Add('')

foreach ($section in $sectionOrder) {
    if ($content[$section].Count -eq 0) {
        continue
    }
    $output.Add("[$section]")
    foreach ($line in $content[$section]) {
        $output.Add($line)
    }
    $output.Add('')
}

if ($unsupported.Count -gt 0) {
    $output.Add('# Unsupported Loon directives retained for manual review')
    foreach ($line in $unsupported) {
        $output.Add('# ' + $line)
    }
    $output.Add('')
}

$output.Add('[MITM]')
$output.Add('hostname = %APPEND% ' + (($hostnames | Sort-Object) -join ', '))
$output.Add('')

$encoding = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputFile, $output, $encoding)

Write-Output "Created: $OutputFile"
Write-Output "Local modules: $($moduleFiles.Count)"
foreach ($section in $sectionOrder) {
    Write-Output "$section`: $($content[$section].Count)"
}
Write-Output "MITM hostnames: $($hostnames.Count)"
Write-Output "Unsupported Loon directives: $($unsupported.Count)"