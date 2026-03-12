param(
  [switch]$SkipVersionCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

function Get-MinDartVersionFromPubspec([string]$pubspecPath) {
  if (-not (Test-Path $pubspecPath)) { return $null }

  $inEnv = $false
  foreach ($raw in Get-Content $pubspecPath) {
    $line = $raw.TrimEnd()
    if ($line -match '^\s*#') { continue }

    if ($line -match '^\s*environment:\s*$') { $inEnv = $true; continue }
    if ($inEnv -and $line -match '^\S') { $inEnv = $false }

    if ($inEnv -and $line -match '^\s*sdk:\s*(.+)$') {
      $spec = $Matches[1]
      $spec = ($spec -split '#', 2)[0].Trim().Trim('"').Trim("'")

      if ($spec -match '^\^(\d+\.\d+\.\d+)') { return $Matches[1] }
      if ($spec -match '^>=\s*(\d+\.\d+\.\d+)') { return $Matches[1] }
      if ($spec -match '^(\d+\.\d+\.\d+)$') { return $Matches[1] }

      return $null
    }
  }

  return $null
}

Assert-Command flutter
Assert-Command dart

$expectedFlutter = '3.38.4'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Assert-InfraRequirementsPinned() {
  $req = Join-Path $repoRoot "infra/requirements.txt"
  if (-not (Test-Path $req)) { return }

  $bad = @()
  foreach ($raw in Get-Content $req) {
    $line = $raw.Trim()
    if (-not $line -or $line.StartsWith("#")) { continue }
    if ($line.StartsWith("-")) { continue } # pip options like -r, --index-url, etc.
    if ($line -notmatch "==") { $bad += $line }
  }

  if ($bad.Count -gt 0) {
    $msg = ($bad | Select-Object -First 10) -join "; "
    throw "infra/requirements.txt must pin versions with '=='. Unpinned line(s): ${msg}"
  }
}

if (-not $SkipVersionCheck) {
  $frameworkVersion = $null
  try {
    $machine = flutter --version --machine | ConvertFrom-Json
    $frameworkVersion = $machine.frameworkVersion
  } catch {
    $frameworkVersion = $null
  }

  if (-not $frameworkVersion) {
    $versionOutput = flutter --version
    $firstLine = $versionOutput | Select-Object -First 1
    if ($firstLine -notmatch [Regex]::Escape("Flutter $expectedFlutter")) {
      throw "Unexpected Flutter version. Expected $expectedFlutter but got: $firstLine`nTip: rerun with -SkipVersionCheck to bypass."
    }
  } elseif ($frameworkVersion -ne $expectedFlutter) {
    throw "Unexpected Flutter version. Expected $expectedFlutter but got: $frameworkVersion`nTip: rerun with -SkipVersionCheck to bypass."
  }

  $minDart = $env:MIN_DART_VERSION
  if (-not $minDart) {
    $minDart = Get-MinDartVersionFromPubspec (Join-Path $repoRoot "pubspec.yaml")
  }

  if ($minDart) {
    $dartVersionOutput = (dart --version 2>&1) | Out-String
    $installed = $null
    if ($dartVersionOutput -match '(\d+\.\d+\.\d+)') { $installed = $Matches[1] }
    if (-not $installed) { throw "Could not determine installed Dart version from: $dartVersionOutput" }

    if ([Version]$installed -lt [Version]$minDart) {
      throw "Dart SDK $installed is below pubspec minimum $minDart.`nTip: rerun with -SkipVersionCheck to bypass."
    }
  }
}

Push-Location $repoRoot
try {
  if (($env:CI -eq "true") -or ($env:GITHUB_ACTIONS -eq "true")) {
    $envFiles = @()
    $envFiles += Get-ChildItem -File -Force -Path ".env" -ErrorAction SilentlyContinue
    $envFiles += Get-ChildItem -File -Force -Path ".env.*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".env.example" }
    if ($envFiles.Count -gt 0) {
      $names = ($envFiles | Select-Object -ExpandProperty Name | Sort-Object -Unique) -join ", "
      throw "Refusing to run in CI: env file(s) exist in the repo checkout (${names}). Remove them from version control."
    }
    if (Test-Path "infra/.venv") { throw "Refusing to run in CI: infra/.venv exists in the repo checkout. Remove it from version control." }
  }

  Assert-InfraRequirementsPinned

  flutter pub get

  if (($env:CI -eq "true") -or ($env:GITHUB_ACTIONS -eq "true")) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
      & git rev-parse --is-inside-work-tree *> $null
      if ($LASTEXITCODE -eq 0) {
        & git diff --exit-code -- pubspec.lock *> $null
        if ($LASTEXITCODE -ne 0) {
          Write-Error "pubspec.lock changed after 'flutter pub get'. Commit the updated lockfile."
          & git diff -- pubspec.lock
          exit 1
        }
      }
    }
  }

  $formatTargets = @()
  if (Test-Path "lib") { $formatTargets += "lib" }
  if (Test-Path "test") { $formatTargets += "test" }
  if ($formatTargets.Count -gt 0) {
    dart format --output=none --set-exit-if-changed @formatTargets
  }

  flutter analyze
  flutter test
} finally {
  Pop-Location
}
