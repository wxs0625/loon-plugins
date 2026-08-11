$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'Loon_All_In_One_Fixed_Shadowrocket.sgmodule'
$outputPath = Join-Path $PSScriptRoot 'Loon_All_In_One_Fixed_Shadowrocket_v2.sgmodule'

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source module not found: $sourcePath"
}
$sourceHashBefore = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$lines = [IO.File]::ReadAllLines($sourcePath, [Text.Encoding]::UTF8)
$result = New-Object 'System.Collections.Generic.List[string]'
$section = ''
$zongHengRuleAdded = $false

$youtubeRewritePatterns = @(
    '(?i)googlevideo\\\.com\\/initplayback',
    '^\^https\?:\\/\\/\.\+\\\.googleapis\.com/\.\+ad_break',
    '^\^https\?:\\/\\/\.\+\\\.googleapis\.com/\.\+log_event',
    '^\^https\?:\\/\\/\.\+\\\.googleapis\.com/adsmeasurement'
)

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[(.+)\]$') {
        $section = $Matches[1]
        $result.Add($line)
        continue
    }

    if ($line -like '#!name=*') {
        $result.Add('#!name=All In One Fixed - Shadowrocket v2')
        continue
    }
    if ($line -like '#!desc=*') {
        $result.Add('#!desc=Independent v2: ZongHeng startup fix and low-latency YouTube networking')
        continue
    }
    if ($line -like '#!date=*') {
        $result.Add("#!date=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        continue
    }

    if ($section -eq 'URL Rewrite') {
        $isYouTubeRewrite = $false
        foreach ($pattern in $youtubeRewritePatterns) {
            if ($trimmed -match $pattern) {
                $isYouTubeRewrite = $true
                break
            }
        }
        if ($isYouTubeRewrite) {
            continue
        }

        if ($trimmed -match '(?i)zongheng\\?\.com.*iosapi\\?/system\\?/startup') {
            if (-not $zongHengRuleAdded) {
                $result.Add('^https?:\/\/[^\/]*\.zongheng\.com\/iosapi\/system\/startup(?:\?.*)?$ - reject-200')
                $zongHengRuleAdded = $true
            }
            continue
        }
    }

    if ($section -eq 'Script' -and $trimmed -match '(?i)youtubei\\\.googleapis\\\.com|youtube\.response\.js|^YouTube') {
        continue
    }

    if ($section -eq 'MITM' -and $trimmed -match '^hostname\s*=') {
        $prefix, $hostText = $line -split '=', 2
        $hosts = $hostText -split ',' | ForEach-Object { $_.Trim() } | Where-Object {
            $_ -and $_ -notin @('*.googleapis.com', 'rr*.googlevideo.com', 'youtubei.googleapis.com')
        }
        $result.Add("$($prefix.TrimEnd()) = $($hosts -join ', ')")
        continue
    }

    $result.Add($line)
}

if (-not $zongHengRuleAdded) {
    throw 'The original ZongHeng startup rule was not found.'
}

$utf8Bom = New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllLines($outputPath, $result, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    Remove-Item -LiteralPath $outputPath -Force
    throw 'The source module changed during the build.'
}

Write-Output "Created: $outputPath"
Write-Output "Source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash)"