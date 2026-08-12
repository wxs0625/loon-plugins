param(
    [string]$SourceModule = (Join-Path $PSScriptRoot 'v4_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'Battery_FullAds_Loon_All_In_One_Fixed_Shadowrocket.sgmodule')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceModule -PathType Leaf)) {
    throw "Source module not found: $SourceModule"
}

$sourceHashBefore = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
$removedScripts = [System.Collections.Generic.List[string]]::new()
$removedBodyRewrites = [System.Collections.Generic.List[string]]::new()
$result = [System.Collections.Generic.List[string]]::new()
$section = ''

$nonAdScriptPatterns = @(
    'Spotify\.Crack\.Dev\.js',
    'Coolapk_Redirect\.js',
    'UnblockURLinWeChat\.js',
    'Weixin_external_links_unlock\.js',
    'WeatherKit/releases/download/.+/response\.bundle\.js',
    'pattern=.+client\\?/light_skin',
    'pattern=.+littleskin\\?/preview',
    'weibo_vip\.js',
    'pattern=.+comment\\?/video\\?/download.+xiaohongshu\.js',
    'pattern=.+comment\\?/(?:list|sub_comments).+xiaohongshu\.js',
    'pattern=.+note\\?/(?:imagefeed|live_photo\\?/save).+xiaohongshu\.js',
    'pattern=.+note\\?/(?:feed|videofeed).+xiaohongshu\.js',
    'pattern=.+note\\?/video\\?/save.+xiaohongshu\.js',
    'pattern=.+interaction\\?/comment\\?/video\\?/download.+RedPaper_remove_ads\.js',
    'pattern=.+note\\?/(?:imagefeed|live_photo\\?/save).+RedPaper_remove_ads\.js',
    'pattern=.+note\\?/(?:feed|videofeed).+RedPaper_remove_ads\.js',
    'pattern=.+note\\?/video\\?/save.+RedPaper_remove_ads\.js'
)

$nonAdBodyPatterns = @(
    'account\\?/myinfo.*due_date',
    'pgc\\?/view\\?/v2\\?/app\\?/season.*payment',
    'play\\?\.ups\\?\.appinfo\\?\.get.*watermark',
    'bottom_theme.*theme_list',
    'posters\\?\.meitu\\?\.com.*\["data","vip"\]',
    'miyoushe\\?\.com.*teenager',
    'api\\?\.zhihu\\?\.com\\?/people\\?/self.*vip_info'
)

foreach ($line in [System.IO.File]::ReadAllLines($SourceModule, [System.Text.Encoding]::UTF8)) {
    $trimmed = $line.Trim()

    if ($trimmed -match '^\[([^]]+)\]$') {
        $section = $Matches[1]
        $result.Add($line)
        continue
    }

    if ($line -like '#!name=*') {
        $result.Add('#!name=All In One Fixed - Shadowrocket Battery Full Ads')
        continue
    }
    if ($line -like '#!desc=*') {
        $result.Add('#!desc=Battery edition preserving all ad blocking; removes only verified non-ad enhancements')
        continue
    }
    if ($line -like '#!date=*') {
        $result.Add('#!date=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        continue
    }

    if ($section -eq 'Script' -and $trimmed -match '^(.+?)\s*=\s*type=http-(?:request|response),') {
        $scriptName = $Matches[1].Trim()
        $removeScript = $false
        foreach ($pattern in $nonAdScriptPatterns) {
            if ($trimmed -match $pattern) {
                $removeScript = $true
                break
            }
        }
        if ($removeScript) {
            $removedScripts.Add($scriptName)
            continue
        }
    }

    if ($section -eq 'Body Rewrite') {
        $removeBodyRewrite = $false
        foreach ($pattern in $nonAdBodyPatterns) {
            if ($trimmed -match $pattern) {
                $removeBodyRewrite = $true
                break
            }
        }
        if ($removeBodyRewrite) {
            $removedBodyRewrites.Add($trimmed)
            continue
        }
    }

    $result.Add($line)
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputFile, $result, $utf8Bom)

$sourceHashAfter = (Get-FileHash -LiteralPath $SourceModule -Algorithm SHA256).Hash
if ($sourceHashBefore -ne $sourceHashAfter) {
    Remove-Item -LiteralPath $OutputFile -Force
    throw 'The v4 source module changed during the build.'
}

Write-Output "Created: $OutputFile"
Write-Output "v4 source SHA256 (unchanged): $sourceHashAfter"
Write-Output "Output SHA256: $((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash)"
Write-Output "Removed non-ad scripts: $($removedScripts.Count)"
$removedScripts | ForEach-Object { Write-Output "  SCRIPT: $_" }
Write-Output "Removed non-ad body rewrites: $($removedBodyRewrites.Count)"
$removedBodyRewrites | ForEach-Object { Write-Output "  BODY: $_" }