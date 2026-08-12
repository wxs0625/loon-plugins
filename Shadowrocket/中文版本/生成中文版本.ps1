param(
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-Utf8Base64 {
    param([string]$Value)

    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$versions = @(
    @{ Source = 'Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzEuMC5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDEuMA=='; Desc = '5Yid5aeL6ZuG5ZCI54mI5pys' },
    @{ Source = 'v2_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzIuMC5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDIuMA=='; Desc = '56ys5LqM5Liq5Li76KaB54mI5pys' },
    @{ Source = 'v3_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuMC5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuMA=='; Desc = '56ys5LiJ5Liq5Li76KaB54mI5pys' },
    @{ Source = 'v4_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuMS5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuMQ=='; Desc = 'My4wIOeahOesrOS4gOS4quWwj+eJiOacrA==' },
    @{ Source = 'v3_Energy_Saving_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuMi5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuMg=='; Desc = 'My4wIOeahOesrOS6jOS4quWwj+eJiOacrA==' },
    @{ Source = 'v3_Balanced_Energy_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuMy5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuMw=='; Desc = 'My4wIOeahOesrOS4ieS4quWwj+eJiOacrA==' },
    @{ Source = 'v3_Balanced_Energy_Fixed_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuNC5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuNA=='; Desc = 'My4wIOeahOesrOWbm+S4quWwj+eJiOacrA==' },
    @{ Source = 'v3_Balanced_Energy_Fixed_WeChat_Official_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuNS5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuNQ=='; Desc = 'My4wIOeahOesrOS6lOS4quWwj+eJiOacrA==' },
    @{ Source = 'v3_Balanced_Energy_Fixed_WeChat_Official_Enhanced_Loon_All_In_One_Fixed_Shadowrocket.sgmodule'; Target = '6ZuG5ZCI5L+u5aSN54mIXzMuNi5zZ21vZHVsZQ=='; Name = '6ZuG5ZCI5L+u5aSN54mIIDMuNg=='; Desc = 'My4wIOeahOesrOWFreS4quWwj+eJiOacrA==' },
    @{ Source = 'Weibo_No_Ads_Shadowrocket.sgmodule'; Target = '54us56uL5qih5Z2XXzEuMC5zZ21vZHVsZQ=='; Name = '54us56uL5qih5Z2XIDEuMA=='; Desc = '5LiO6ZuG5ZCI54mI5pys57q/5YiG5byA57u05oqk55qE54us56uL5qih5Z2X' }
)

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
$created = [System.Collections.Generic.List[string]]::new()

foreach ($version in $versions) {
    $sourcePath = Join-Path $Root $version.Source
    $targetName = ConvertFrom-Utf8Base64 $version.Target
    $displayName = ConvertFrom-Utf8Base64 $version.Name
    $description = ConvertFrom-Utf8Base64 $version.Desc
    $targetPath = Join-Path $Root $targetName

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Source module not found: $sourcePath"
    }
    if (Test-Path -LiteralPath $targetPath) {
        throw "Target already exists; refusing to overwrite: $targetPath"
    }

    $sourceHashBefore = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $lines = [System.IO.File]::ReadAllLines($sourcePath, [System.Text.Encoding]::UTF8)
    $nameCount = 0
    $descCount = 0

    for ($index = 0; $index -lt $lines.Length; $index++) {
        if ($lines[$index] -like '#!name=*') {
            $lines[$index] = '#!name=' + $displayName
            $nameCount++
        } elseif ($lines[$index] -like '#!desc=*') {
            $lines[$index] = '#!desc=' + $description
            $descCount++
        }
    }

    if ($nameCount -ne 1 -or $descCount -ne 1) {
        throw "Unexpected metadata count in $($version.Source): name=$nameCount, desc=$descCount"
    }

    [System.IO.File]::WriteAllLines($targetPath, $lines, $utf8Bom)
    $sourceHashAfter = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($sourceHashAfter -ne $sourceHashBefore) {
        Remove-Item -LiteralPath $targetPath -Force
        throw "Source changed while creating $($version.Target)"
    }

    $created.Add($targetPath)
}

foreach ($path in $created) {
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    Write-Output "Created: $path"
    Write-Output "SHA256: $hash"
}