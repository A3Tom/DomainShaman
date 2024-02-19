git fetch --tags
$tags = git tag

$versionTags = $tags | Where-Object { $_ -like 'release/v*' } | ForEach-Object { $_ -replace "release/v", "" }

$versions = $versionTags | ForEach-Object { [System.Version]::new($_) } | Sort-Object 
Write-Host "All semantic version tags: $versions"

$latestVersion = $versions[-1]
$latestTag =  $latestVersion.ToString()

$nextPatchVersion = $latestVersion.Major, $latestVersion.Minor, ($latestVersion.Build + 1) -join "."
$nextMinorVersion = $latestVersion.Major, ($latestVersion.Minor + 1), 0 -join "."

Write-Host "The most recent semantic version tag is: v$latestTag"
Write-Host "Next patch version: $nextPatchVersion"
Write-Host "Next minor version: $nextMinorVersion"
