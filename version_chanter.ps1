git config user.name github-actions
git config user.email github-actions@github.com
git fetch
$pipelineProvider = "github"
$minorVersionMergeSources = @("feature")

function Assert-IsGithubMergeCommit {
    param (
        [string]$targetCommitMessage
    )

    Write-Host "Target Commit Message: $targetCommitMessage"

    If ($targetCommitMessage -Match 'Merge: [a-z0-9]{7}\s[a-z0-9]{7}') {
        Write-Host "This is a merge commit. Sound tae proceed."
        return $true
    }
    
    Write-Error "This is not a merge commit. Skipping versioning." -Category InvalidArgument
    exit 1
}

function Assert-IsMergeCommit {
    param (
        [string]$targetCommitMessage
    )

    Write-Host "Pipeline provider: $pipelineProvider"

    if ($pipelineProvider -eq "github") {
        Assert-IsGithubMergeCommit -targetCommitMessage $targetCommitMessage
    } elseif ($pipelineProvider -eq "azure") {
        Write-Error "Here mate, let me get GH Actions sorted first"
        exit 1
    } else {
        Write-Error "Unsupported pipeline provider: $pipelineProvider"
        exit 1
    }
}

function Assert-IsArgumentValidCommitId {
    param (
        [string]$commitId
    )

    if ($null -eq $commitId) {
        Write-Error "Please provide a commit id as the first argument" -Category InvalidArgument
        exit 1
    }
    
    $true
}

function Set-TargetCommitId {
    param (
        [string]$commitId
    )
    if (Assert-IsArgumentValidCommitId -commitId $commitId){
        $targetCommitId = $commitId
    }
    $targetCommitId
}

function Get-MergeSourceBranchRegex {
    $branchNames = $minorVersionMergeSources -join "|"
    "^(?:$branchNames)\/\S+"
}

function Assert-IsMinorVersionIncrement {
    param (
        [string]$sourceBranchName
    )
    $minorVersionMergeSourceRegex = Get-MergeSourceBranchRegex
    $minorVersionBranchNames = $minorVersionMergeSources -join ", "
    If ($sourceBranchName -match $minorVersionMergeSourceRegex) {
        Write-Host "[$minorVersionBranchNames] match found in branch: $sourceBranchName. Increasin the minor version."
        return $true
    }

    Write-Host "[$minorVersionBranchNames] match not found in branch: $sourceBranchName. Increasin the patch version."
    $false
}


function Get-CurrentReleaseVersions {
    $tags = git tag
    $tags | Where-Object { $_ -like 'release/v*' } | ForEach-Object { $_ -replace "release/v", "" }
}

function Get-CurrentVersion {
    param (
        [object[]]$tags
    )
    $versionTags = Get-CurrentReleaseVersions
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

    $nextVersion = if ($isMinorRevision) { $nextMinorVersion } else { $nextPatchVersion }
    Write-Host "Next version: $nextVersion"

    $nextVersion
}

function Set-NextVersionTag {
    param (
        [System.Version]$nextVersion,
        [string]$targetCommitId
    )

    Write-Host "Settin phasers tae malky"
    git tag -a "release/v$nextVersion" $targetCommitId -m "Release v$nextVersion"
    git push --tag
}

$commitId = Set-TargetCommitId -commitId $args[0]
$isMinorRevision = Assert-IsMinorVersionIncrement -sourceBranchName $args[1]
$latestVersion = Get-CurrentVersion -tags $tags
$nextVersion = Get-NextVersion -latestVersion $latestVersion -isMinorRevision $isMinorRevision

Set-NextVersionTag -nextVersion $nextVersion -targetCommitId $commitId
