#requires -Version 5.1

<#
.SYNOPSIS
    Saves git diff output to a file.

.DESCRIPTION
    This script runs 'git add --all' to stage all changes, then runs 'git diff --cached' 
    and saves the output to a specified file. The script confirms the repository and branch
    with the user before proceeding.

.PARAMETER OutputFile
    The path to the file where the git diff output will be saved.
    Default is 'git-diff.txt' in the current directory.

.PARAMETER SkipConfirmation
    If specified, skips the confirmation step.

.EXAMPLE
    .\Save-GitDiff.ps1
    Saves the git diff output to git-diff.txt in the current directory.

.EXAMPLE
    .\Save-GitDiff.ps1 -OutputFile "C:\temp\my-changes.diff"
    Saves the git diff output to the specified file path.

.EXAMPLE
    .\Save-GitDiff.ps1 -SkipConfirmation
    Skips the confirmation step and proceeds directly.
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$OutputFile = "git-diff.txt",
    
    [Parameter()]
    [switch]$SkipConfirmation
)

# Verify git is installed
try {
    $null = Get-Command git -ErrorAction Stop
}
catch {
    Write-Error "Git is not installed or not in the PATH. Please install Git or add it to your PATH."
    exit 1
}

# Verify we're in a git repository
if (-not (Test-Path -Path ".git" -PathType Container)) {
    Write-Error "This directory is not a git repository. Please run this script from a git repository."
    exit 1
}

# Get repository and branch information
try {
    $repoName = Split-Path -Path (git rev-parse --show-toplevel) -Leaf
    $currentBranch = git rev-parse --abbrev-ref HEAD
}
catch {
    Write-Error "Failed to get repository information: $_"
    exit 1
}

# Confirm with user
if (-not $SkipConfirmation) {
    Write-Host "Current repository: $repoName" -ForegroundColor Cyan
    Write-Host "Current branch: $currentBranch" -ForegroundColor Cyan
    
    # Get list of staged and unstaged changes
    $allChanges = git status --porcelain
    
    # Filter for unstaged changes (those not fully staged)
    $unstagedChanges = $allChanges | Where-Object { 
        $_ -match '^.[MADRCU?]' -or $_ -match '^\?\?' 
    }
    
    # Filter for already staged changes
    $stagedChanges = $allChanges | Where-Object { 
        $_ -match '^[MADRCU]' -and $_ -notmatch '^.[MADRCU?]' 
    }
    
    $unstagedCount = ($unstagedChanges | Measure-Object).Count
    $stagedCount = ($stagedChanges | Measure-Object).Count
    
    # Show already staged changes
    if ($stagedCount -gt 0) {
        Write-Host "`nAlready staged changes ($stagedCount):" -ForegroundColor Green
        $stagedChanges | ForEach-Object {
            $status = $_.Substring(0, 2)
            $file = $_.Substring(3)
            
            $statusText = switch -Regex ($status) {
                '^M.'   { "Modified:   " }
                '^A.'   { "Added:      " }
                '^D.'   { "Deleted:    " }
                '^R.'   { "Renamed:    " }
                '^C.'   { "Copied:     " }
                default { "Changed:    " }
            }
            
            Write-Host "  $statusText$file" -ForegroundColor DarkGreen
        }
    }
    
    # Show new changes to be staged
    Write-Host "`nNew changes to be staged ($unstagedCount):" -ForegroundColor Yellow
    if ($unstagedCount -gt 0) {
        $unstagedChanges | ForEach-Object {
            $status = $_.Substring(0, 2)
            $file = $_.Substring(3)
            
            $statusText = switch -Regex ($status) {
                '^\?\?' { "Untracked:  " }
                '^.M'   { "Modified:   " }
                '^.A'   { "Added:      " }
                '^.D'   { "Deleted:    " }
                '^.R'   { "Renamed:    " }
                '^.C'   { "Copied:     " }
                default { "Changed:    " }
            }
            
            Write-Host "  $statusText$file"
        }
    } else {
        Write-Host "  No new changes to stage" -ForegroundColor Gray
    }
    
    # If no changes at all
    if ($stagedCount -eq 0 -and $unstagedCount -eq 0) {
        Write-Host "  No changes detected in this repository" -ForegroundColor Gray
    }
    
    Write-Host "`nThis script will stage all changes with 'git add --all' and save the diff to $OutputFile" -ForegroundColor Yellow
    
    $confirmation = Read-Host -Prompt "Do you want to proceed? (Y/N)"
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Red
        exit 0
    }
}

# Stage all changes
try {
    Write-Verbose "Staging all changes with 'git add --all'"
    git add --all
    
    # Unstage the output file if it was staged
    # This prevents the output file from being part of the diff
    if (Test-Path -Path $OutputFile) {
        Write-Verbose "Unstaging output file: $OutputFile"
        git reset HEAD $OutputFile
    }
    
    Write-Host "All changes have been staged (except the output file)" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred while staging changes: $_"
    exit 1
}

# Get the git diff and save it to the file
try {
    Write-Verbose "Running 'git diff --cached' and saving to $OutputFile"
    
    # First, remove the file if it exists - with extra verification
    if (Test-Path -Path $OutputFile) {
        try {
            Remove-Item -Path $OutputFile -Force -ErrorAction Stop
            Write-Verbose "Removed existing file: $OutputFile"
            # Verify removal
            if (Test-Path -Path $OutputFile) {
                Write-Error "Failed to remove existing file: $OutputFile"
                exit 1
            }
        }
        catch {
            Write-Error "Error removing file: $_"
            exit 1
        }
    }
    
    # Get the diff content
    $diffOutput = git diff --cached
    
    # Create a new file with the diff content
    if ($null -eq $diffOutput -or $diffOutput -eq '') {
        Write-Warning "No staged changes found. The output file will be empty."
        # Create an empty file
        Set-Content -Path $OutputFile -Value "" -Force
    } else {
        # Restore original behavior but ensure we're creating a new file
        # This preserves line breaks properly
        Set-Content -Path $OutputFile -Value $diffOutput -Encoding UTF8 -Force
    }
    
    Write-Host "Git diff output saved to $OutputFile"
}
catch {
    Write-Error "An error occurred while running git diff: $_"
    exit 1
} 