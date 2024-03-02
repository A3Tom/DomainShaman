git fetch --tags
$tags = git tag
#$mostRecentCommit = git log -1
$targetCommitId = "e967c221e439ffe4dfcf0c7d985dd012fe48c0af"
$mostRecentCommit = git log $targetCommitId -1
$pipelineProvider = "github"
$minorVersionMergeSources = @("bugfix", "slampy")

function Get-MergeSourceBranchRegex {
    # Maybe make case agnostic ? 
    $branchNames = $minorVersionMergeSources -join "|"
    "[from\w]\S+[\/](?:$branchNames)\/\S+"
}

function Assert-IncrementMinorVersion {
    $minorVersionMergeSources = Get-MergeSourceBranchRegex
    If ($mostRecentCommit -match $minorVersionMergeSources) {
        return $true
    }
    $false
}

function Assert-IsGithubMergeCommit {
    Write-Host "Checking if this is a merge commit $mostRecentCommit"
    If ($mostRecentCommit -match 'Merge: [a-z0-9]{7}\s[a-z0-9]{7}') {
        Write-Host "$_"
        $true
    }
    $false
}

function Get-IsMergeCommit {
    Write-Host "Pipeline provider: $pipelineProvider"

    if ($pipelineProvider -eq "github") {
        Assert-IsGithubMergeCommit
    } elseif ($pipelineProvider -eq "azure") {
        $false
    } else {
        Write-Host "Unsupported pipeline provider: $pipelineProvider"
    }
}

function Get-CurrentVersion {
    param (
        [object[]]$tags
    )
    $versionTags = $tags | Where-Object { $_ -like 'release/v*' } | ForEach-Object { $_ -replace "release/v", "" }
    $versions = $versionTags | ForEach-Object { [System.Version]::new($_) } | Sort-Object 

    $currentVersion = $versions[-1]
    $currentVersionFormat = $currentVersion.Major, $currentVersion.Minor, $currentVersion.Build -join "."
    Write-Host "Current version: $currentVersionFormat"

    $currentVersion
}

function Get-NextVersion {
    param (
        [System.Version]$latestVersion,
        [bool]$isMinorRevision
    )
    $nextMinorVersion = $latestVersion.Major, ($latestVersion.Minor + 1), 0 -join "."
    $nextPatchVersion = $latestVersion.Major, $latestVersion.Minor, ($latestVersion.Build + 1) -join "."
    Write-Host "Next minor version: $nextMinorVersion"
    Write-Host "Next patch version: $nextPatchVersion"

    if ($isMinorRevision) {
        $nextMinorVersion
    } else {
        $nextPatchVersion
    }
}


$isMergeVersion = Get-IsMergeCommit 

if (!$isMergeVersion)
{
    Write-Host "This is not a merge commit. Skipping versioning."
    exit 0
}
Write-Host "This is a merge commit. Proceeding with versioning."

$isMinorRevision = Assert-IncrementMinorVersion
Write-Host "Is minor revision: $isMinorRevision"

$latestVersion = Get-CurrentVersion -tags $tags
$nextVersion = Get-NextVersion -latestVersion $latestVersion -isMinorRevision $isMinorRevision

Write-Host "Next version: $nextVersion"

# Tag git commit
git tag -a "release/v$nextVersion" -m "Release v$nextVersion"
git push --tag
