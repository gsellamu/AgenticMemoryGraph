# commit_and_label.ps1
# Git add, commit, push and tag with version labeling

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Blue   { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Green  { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Yellow { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Red    { param($msg) Write-Host $msg -ForegroundColor Red }

Write-Blue "========================================"
Write-Blue "   Git Commit and Label Script"
Write-Blue "========================================"
Write-Host ""

# Check if we're in a git repository
git rev-parse --is-inside-work-tree > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Red "Error: Not in a git repository"
    exit 1
}

# Get repository info
$repo_url = git remote get-url origin 2>$null
if (-not $repo_url) { $repo_url = "No remote configured" }
$current_branch = git branch --show-current

Write-Green "Repository: $repo_url"
Write-Green "Branch:     $current_branch"
Write-Host ""

# Get the latest version tag
Write-Yellow "Fetching latest version tag..."
$latest_tag = git tag -l "v*" --sort=-v:refname | Select-Object -First 1

if (-not $latest_tag) {
    Write-Yellow "No existing version tags found. Starting with v0.0.0"
    $latest_tag = "v0.0.0"
}

Write-Green "Latest version tag: $latest_tag"

# Parse version numbers using [Regex]
$version_regex = "^v(\d+)\.(\d+)\.(\d+)$"
if ($latest_tag -match $version_regex) {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
} else {
    Write-Red "Error: Could not parse version from tag: $latest_tag"
    Write-Yellow "Expected format: vX.Y.Z (e.g., v1.2.3)"
    $major = 0; $minor = 0; $patch = 0
}

# Increment options
$new_patch = $patch + 1
$new_minor = $minor + 1
$new_major = $major + 1

Write-Host ""
Write-Yellow "Version increment options:"
Write-Host "  1) Patch: v$major.$minor.$new_patch (bug fixes)"
Write-Host "  2) Minor: v$major.$new_minor.0 (new features)"
Write-Host "  3) Major: v$new_major.0.0 (breaking changes)"
Write-Host "  4) Custom version"
Write-Host ""

$version_choice = Read-Host "Select version type [1-4] (default: 1)"
if ([string]::IsNullOrWhiteSpace($version_choice)) { $version_choice = "1" }

switch ($version_choice) {
    "1" { $label_version = "v$major.$minor.$new_patch" }
    "2" { $label_version = "v$major.$new_minor.0" }
    "3" { $label_version = "v$new_major.0.0" }
    "4" { $label_version = Read-Host "Enter custom version (e.g., v1.2.3)" }
    Default { $label_version = "v$major.$minor.$new_patch" }
}

Write-Host ""
Write-Green "New version will be: $label_version"
$confirmed_version = Read-Host "Confirm version [$label_version] (press Enter to confirm or type new version)"
if (-not [string]::IsNullOrWhiteSpace($confirmed_version)) {
    $label_version = $confirmed_version
}

# Check if tag already exists
$existing = git tag -l $label_version
if ($existing -eq $label_version) {
    Write-Red "Error: Tag $label_version already exists!"
    exit 1
}

# Get commit message
Write-Host ""
Write-Yellow "Enter commit message (what changed in this release):"
$commit_message = Read-Host "> "

if ([string]::IsNullOrWhiteSpace($commit_message)) {
    Write-Red "Error: Commit message cannot be empty"
    exit 1
}

# Summary
Write-Blue "========================================"
Write-Blue "   Summary"
Write-Blue "========================================"
Write-Green "Repository: $repo_url"
Write-Green "Branch:     $current_branch"
Write-Green "Version:    $label_version"
Write-Green "Message:    $commit_message"
Write-Host ""

# Status
Write-Yellow "Files to be committed:"
git status --short
Write-Host ""

# Confirm
$confirm = Read-Host "Proceed with commit and tag? [y/N]"
if ($confirm -notmatch "^[Yy]$") {
    Write-Yellow "Aborted."
    exit 0
}

# Execution
Write-Yellow "Adding files..."
git add .

Write-Yellow "Creating commit..."
$full_message = "Release version $label_version : $commit_message`n`nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git commit -m $full_message

Write-Yellow "Creating tag..."
git tag -a "$label_version" -m "Release version $label_version : $commit_message"

Write-Yellow "Pushing commit to origin..."
git push origin HEAD

Write-Yellow "Pushing tag to origin..."
git push origin "$label_version"

Write-Host ""
Write-Green "========================================"
Write-Green "   Success!"
Write-Green "========================================"
Write-Green "Version $label_version has been committed, tagged, and pushed."
Write-Host ""

# List tags
Write-Blue "========================================"
Write-Blue "   All Version Tags"
Write-Blue "========================================"
Write-Host ""
Write-Yellow "Tag            Date                 Message"
Write-Yellow "---            ----                 -------"

$tag_data = git for-each-ref --sort=-creatordate --format='%(refname:short)|%(creatordate:short)|%(subject)' refs/tags
foreach ($line in $tag_data) {
    $parts = $line.Split('|')
    if ($parts.Count -ge 3) {
        "{0,-14} {1,-20} {2}" -f $parts[0], $parts[1], $parts[2]
    }
}
Write-Host ""
