<#
  IC Companion - Cowork session prep
  Runs the pre-session steps from the dev spec:
    1. Verify a clean, synced baseline on master
    2. Create + push the 'v1-live' rollback tag
    3. Scaffold the content/ handoff folder (README + template + .gitkeep)
    4. Commit + push the scaffolding
    5. Print the manual steps that can't be scripted

  Usage:
    powershell -ExecutionPolicy Bypass -File .\prep-cowork-session.ps1
    powershell -ExecutionPolicy Bypass -File .\prep-cowork-session.ps1 -SkipPush

  Idempotent: safe to run more than once.
#>

param(
  [string]$RepoPath = 'C:\_Archive\_IC_WebDev',
  [string]$Tag      = 'v1-live',
  [switch]$SkipPush
)

$ErrorActionPreference = 'Continue'   # we check $LASTEXITCODE ourselves
# On PowerShell 7.3+, stop git's informational stderr from being treated as an error:
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)  { Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Die($m) { Write-Host "`n[stop] $m" -ForegroundColor Red; exit 1 }

# --- 0. Enter the repo -------------------------------------------------------
Step "Entering repo: $RepoPath"
if (-not (Test-Path $RepoPath)) { Die "Folder not found: $RepoPath" }
Set-Location $RepoPath
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { Die "This folder is not a git repository." }
Ok "In git repo."

# --- 1. Baseline: branch, clean tree, sync -----------------------------------
Step "Checking baseline (branch / clean tree / sync with origin)"
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'master') { Warn "You are on '$branch', not 'master'. Prep assumes master." }

$dirty = git status --porcelain
if ($dirty) {
  Warn "Uncommitted changes detected:"
  git status --short
  Die "Commit, stash, or discard these first, then re-run (prep won't mix them into the scaffolding commit)."
}
Ok "Working tree is clean."

git fetch origin master --quiet 2>$null
$local  = git rev-parse master 2>$null
$remote = git rev-parse origin/master 2>$null
if ($local -and $remote) {
  if ($local.Trim() -ne $remote.Trim()) {
    Die "master and origin/master differ - run 'git pull origin master' first, then re-run."
  }
  Ok "In sync with origin/master."
} else {
  Warn "Couldn't compare with origin/master; make sure the repo is pushed."
}

# --- 2. Rollback anchor tag --------------------------------------------------
Step "Creating rollback tag '$Tag'"
if (git tag --list $Tag) {
  Ok "Tag '$Tag' already exists - leaving the original baseline intact."
} else {
  git tag $Tag
  if ($LASTEXITCODE -ne 0) { Die "Failed to create tag '$Tag'." }
  if ($SkipPush) {
    Ok "Tag '$Tag' created locally (push skipped)."
  } else {
    git push origin $Tag
    if ($LASTEXITCODE -ne 0) { Warn "Tag created locally but push failed - push later: git push origin $Tag" }
    else { Ok "Tag '$Tag' created and pushed." }
  }
}

# --- 3. content/ handoff folder + docs ---------------------------------------
Step "Scaffolding content\ handoff folder"
$contentDir = Join-Path $RepoPath 'content'
if (-not (Test-Path $contentDir)) { New-Item -ItemType Directory -Path $contentDir | Out-Null; Ok "Created content\" }
else { Ok "content\ already exists." }

$gitkeep = Join-Path $contentDir '.gitkeep'
if (-not (Test-Path $gitkeep)) { New-Item -ItemType File -Path $gitkeep | Out-Null }

$readme = Join-Path $contentDir 'README.md'
if (-not (Test-Path $readme)) {
@'
# content/ - module content bundles

Each file here is a **content bundle** authored in the research chat and read by Cowork.
Cowork builds these into `index.html`; it does NOT author medical content itself.

A bundle (`<module>.md`) contains:
1. Module metadata - key/id, card title, card subtitle, registry text.
2. Questions - array of `{ id, section, label, type, options?, other?, min?, max?, placeholder? }`
   where type is one of: radio | checkbox | number | select | textarea.
3. Educational copy (optional) - intro/explanatory prose in the app's voice.
4. Results/spec logic (optional) - plain conditions on specific answers.
5. Citations - sources backing any factual claim.

See `_TEMPLATE.md` for a starting point.
'@ | Set-Content -Path $readme -Encoding utf8
}

$template = Join-Path $contentDir '_TEMPLATE.md'
if (-not (Test-Path $template)) {
@'
# <Module Name> - content bundle

## 1. Module metadata
- key:
- card title:
- card subtitle:
- registry text:

## 2. Questions
```js
[
  { id: 0, section: "", label: "", type: "radio", options: ["", ""] }
]
```

## 3. Educational copy (optional)

## 4. Results / spec logic (optional)

## 5. Citations
-
'@ | Set-Content -Path $template -Encoding utf8
}
Ok "content\ ready (README.md, _TEMPLATE.md, .gitkeep)."

# --- 4. Commit + push the scaffolding ----------------------------------------
Step "Committing content scaffolding"
git add content
if (git status --porcelain) {
  git commit -m "Add content/ handoff folder and bundle docs for Cowork workflow"
  if ($LASTEXITCODE -ne 0) { Die "Commit failed." }
  if ($SkipPush) {
    Ok "Committed locally (push skipped). Push later: git push origin master"
  } else {
    git push origin master
    if ($LASTEXITCODE -ne 0) { Warn "Committed but push failed - push later: git push origin master" }
    else { Ok "Scaffolding committed and pushed (live site rebuilds; app content unchanged)." }
  }
} else {
  Ok "Nothing new to commit - scaffolding already in place."
}

# --- 5. Manual steps ---------------------------------------------------------
Step "Prep complete. Manual steps to finish:"
Write-Host @"
  1. Open Cowork -> create a project -> "Use an existing folder" -> $RepoPath
  2. Paste IC_Companion_Cowork_Dev_Spec.md in as the project's instructions.
  3. Back in the research chat, pick the first module; it produces content\<module>.md
  4. Save that bundle into content\ and tell Cowork to build it.

  Baseline is tagged '$Tag'. To inspect it later:  git checkout $Tag   (then: git checkout master)
"@ -ForegroundColor Gray
