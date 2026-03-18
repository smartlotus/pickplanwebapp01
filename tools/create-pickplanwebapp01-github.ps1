param(
  [string]$ProjectPath = "C:\Users\28389\Desktop\mypickapps\Pickplan",
  [string]$RepoName = "pickplanwebapp01",
  [string]$GitHubOwner = "",
  [string]$Token = "",
  [ValidateSet("User", "Org")]
  [string]$OwnerType = "User",
  [switch]$SkipRepoCreate,
  [switch]$UseSsh,
  [switch]$Public,
  [string]$Branch = "main",
  [string]$WorkDir = ""
)

$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
  $Global:PSNativeCommandUseErrorActionPreference = $false
}

function Invoke-GitCmd {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ArgsLine
  )

  $output = cmd /c ("git " + $ArgsLine + " 2>&1")
  return [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output   = ($output | Out-String)
  }
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
  throw "ProjectPath not found: $ProjectPath"
}

if ([string]::IsNullOrWhiteSpace($WorkDir)) {
  $WorkDir = Join-Path $env:TEMP ($RepoName + "-upload")
}

if ([string]::IsNullOrWhiteSpace($GitHubOwner)) {
  $GitHubOwner = Read-Host "GitHub owner (username or organization)"
}

$needsTokenForApi = (-not $UseSsh.IsPresent) -or (-not $SkipRepoCreate.IsPresent)

if ($needsTokenForApi -and [string]::IsNullOrWhiteSpace($Token)) {
  $secureToken = Read-Host "GitHub token (classic: repo; fine-grained: Contents RW + Metadata R)" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
  try {
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

if ($needsTokenForApi -and [string]::IsNullOrWhiteSpace($Token)) {
  throw "GitHub token is required for this mode."
}

$headers = $null
if (-not [string]::IsNullOrWhiteSpace($Token)) {
  $headers = @{
    Authorization          = "Bearer $Token"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"           = "pickplan-repo-bootstrap"
  }
}

$repoExists = $false
$repoApi = "https://api.github.com/repos/$GitHubOwner/$RepoName"

if ($headers -ne $null) {
  try {
    Invoke-RestMethod -Method Get -Uri $repoApi -Headers $headers | Out-Null
    $repoExists = $true
    Write-Host "GitHub repository already exists: $GitHubOwner/$RepoName"
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -ne 404) {
      throw
    }
  }
}

if (-not $repoExists -and $SkipRepoCreate.IsPresent) {
  if ($headers -ne $null) {
    throw "Repository $GitHubOwner/$RepoName does not exist. Create it on GitHub first, then rerun with -SkipRepoCreate."
  } else {
    Write-Host "SkipRepoCreate + UseSsh mode: skipping GitHub API existence check."
  }
}

if (-not $repoExists -and -not $SkipRepoCreate.IsPresent) {
  if ($headers -eq $null) {
    throw "Repository creation requires GitHub token authentication."
  }

  $body = @{
    name      = $RepoName
    private   = -not $Public.IsPresent
    auto_init = $false
  }

  $createUri = if ($OwnerType -eq "Org") {
    "https://api.github.com/orgs/$GitHubOwner/repos"
  } else {
    "https://api.github.com/user/repos"
  }

  try {
    Invoke-RestMethod `
      -Method Post `
      -Uri $createUri `
      -Headers $headers `
      -Body ($body | ConvertTo-Json -Depth 5) `
      -ContentType "application/json" | Out-Null
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -eq 403) {
      throw "Cannot create repository with this token (403). Use a token with repo creation permission, or create the repository manually and rerun with -SkipRepoCreate."
    }

    throw
  }

  Write-Host "Created GitHub repository: $GitHubOwner/$RepoName"
}

if (Test-Path -LiteralPath $WorkDir) {
  Remove-Item -LiteralPath $WorkDir -Recurse -Force
}

New-Item -ItemType Directory -Path $WorkDir | Out-Null

$excludeDirs = @(
  ".git",
  ".dart_tool",
  ".idea",
  ".npm-cache",
  ".npm-cache-netlify",
  "build",
  "dist",
  "coverage",
  "node_modules"
)

$excludeFiles = @(
  "*.log",
  ".DS_Store",
  ".dev.vars",
  ".dev.vars.*"
)

$robocopyArgs = @(
  $ProjectPath,
  $WorkDir,
  "/MIR",
  "/R:1",
  "/W:1",
  "/NFL",
  "/NDL",
  "/NJH",
  "/NJS",
  "/NP"
)

foreach ($dir in $excludeDirs) {
  $robocopyArgs += "/XD"
  $robocopyArgs += (Join-Path $ProjectPath $dir)
}

$robocopyArgs += "/XF"
$robocopyArgs += $excludeFiles

& robocopy @robocopyArgs | Out-Null
$robocopyCode = $LASTEXITCODE
if ($robocopyCode -ge 8) {
  throw "robocopy failed with exit code $robocopyCode"
}

Push-Location $WorkDir
try {
  git init | Out-Null
  git checkout -B $Branch | Out-Null
  git add .

  git diff --cached --quiet
  if ($LASTEXITCODE -ne 0) {
    git commit -m "Initial upload: Pickplan project" | Out-Null
  }

  $authRemote = ""
  $plainRemote = ""
  if ($UseSsh.IsPresent) {
    $authRemote = "git@github.com:$GitHubOwner/$RepoName.git"
    $plainRemote = $authRemote
  } else {
    $encodedToken = [uri]::EscapeDataString($Token)
    $authRemote = "https://x-access-token:$encodedToken@github.com/$GitHubOwner/$RepoName.git"
    $plainRemote = "https://github.com/$GitHubOwner/$RepoName.git"
  }

  $existingRemotes = git remote
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to list git remotes."
  }
  if ($existingRemotes -contains "origin") {
    git remote remove origin | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to remove existing origin remote."
    }
  }
  git remote add origin $authRemote
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to add origin remote."
  }
  $pushResult = Invoke-GitCmd ("push -u origin " + $Branch)
  if ($pushResult.ExitCode -ne 0) {
    $pushText = $pushResult.Output
    $isNonFastForward =
      $pushText -match "non-fast-forward" -or
      $pushText -match "fetch first" -or
      $pushText -match "rejected"

    if ($isNonFastForward) {
      Write-Host "Push rejected by non-fast-forward. Trying safe fetch + merge..."

      $fetchResult = Invoke-GitCmd ("fetch origin " + $Branch)
      if ($fetchResult.ExitCode -ne 0) {
        throw "Failed to fetch remote '$Branch'. Details:`n$($fetchResult.Output)"
      }

      $isConflict = $false
      $mergeResult = Invoke-GitCmd ("merge --allow-unrelated-histories --no-edit origin/" + $Branch)
      if ($mergeResult.ExitCode -ne 0) {
        $mergeText = $mergeResult.Output
        $isConflict = $mergeText -match "CONFLICT" -or $mergeText -match "Automatic merge failed"

        if ($isConflict) {
          Write-Host "Auto-merge conflict detected. Falling back to force-with-lease push..."
          $null = Invoke-GitCmd "merge --abort"

          $forcePushResult = Invoke-GitCmd ("push -u origin " + $Branch + " --force-with-lease")
          if ($forcePushResult.ExitCode -ne 0) {
            throw "Force push after merge conflict failed. Details:`n$($forcePushResult.Output)"
          }
        } else {
          throw "Auto-merge with remote '$Branch' failed. Resolve conflicts manually. Details:`n$mergeText"
        }
      }

      if (-not $isConflict) {
        $pushRetryResult = Invoke-GitCmd ("push -u origin " + $Branch)
        if ($pushRetryResult.ExitCode -ne 0) {
          throw "Push retry failed for '$Branch'. Details:`n$($pushRetryResult.Output)"
        }
      }
    } else {
      throw "Failed to push branch '$Branch' to origin. Details:`n$pushText"
    }
  }
  git remote set-url origin $plainRemote

  Write-Host ""
  Write-Host "Upload complete."
  Write-Host "Repo URL: https://github.com/$GitHubOwner/$RepoName"
  Write-Host "Standalone upload workspace: $WorkDir"
} finally {
  Pop-Location
}
