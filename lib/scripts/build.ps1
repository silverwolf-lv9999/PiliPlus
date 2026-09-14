param(
    [string]$Arg = '',
    [string]$VersionOverride = ''
)

try {
    $androidVersionName = $null   # 合法的 pubspec / Android 版本名（三段，如 2.1.4），避免 Flutter 校验失败回退成 1.0/1
    $displayVersion = $null       # 应用内展示与文件名的版本号（如 2.1.4.2）

    $versionCode = [int](git rev-list --count HEAD).Trim()

    $commitHash = (git rev-parse HEAD).Trim()

    $updatedContent = foreach ($line in (Get-Content -Path 'pubspec.yaml' -Encoding UTF8)) {
        if ($line -match '^\s*version:\s*(?<base>[\d\.]+)') {
            $baseVersion = $matches['base']
            $androidVersionName = $baseVersion
            if ($VersionOverride -ne '') {
                # 显式指定的 fork 版本号（如 2.1.4.2），只用于应用内展示/文件名，不写进 pubspec（4 段会触发 Flutter 校验回退）
                $displayVersion = $VersionOverride
            }
            else {
                $displayVersion = $baseVersion
                if ($Arg -eq 'android') {
                    $displayVersion += '-' + $commitHash.Substring(0, 9)
                }
            }
            "version: $androidVersionName+$versionCode"
        }
        else {
            $line
        }
    }

    if ($null -eq $androidVersionName) {
        throw 'version not found'
    }

    $updatedContent | Set-Content -Path 'pubspec.yaml' -Encoding UTF8

    $buildTime = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())

    $data = @{
        'pili.name' = $displayVersion
        'pili.code' = $versionCode
        'pili.hash' = $commitHash
        'pili.time' = $buildTime
    }

    $data | ConvertTo-Json -Compress | Out-File 'pili_release.json' -Encoding UTF8

    Add-Content -Path $env:GITHUB_ENV -Value "version=$displayVersion+$versionCode"
    Add-Content -Path $env:GITHUB_ENV -Value "BUILD_NAME=$displayVersion"
    Add-Content -Path $env:GITHUB_ENV -Value "BUILD_NUMBER=$versionCode"
}
catch {
    Write-Error "Prebuild Error: $($_.Exception.Message)"
    exit 1
}