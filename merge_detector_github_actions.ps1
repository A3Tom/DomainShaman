git fetch
$log = git log -1

ForEach-Object { $log -match "Merge pull request" } {
    Write-Host "Merge pull request detected"
}
