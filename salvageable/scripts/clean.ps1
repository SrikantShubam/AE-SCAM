Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot
try {
  $removePaths = @(
    ".dart_tool",
    "build",
    "coverage",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    "android/.gradle",
    "android/app/build",
    "android/build",
    "infra/.venv",
    "litellm.log",
    "litellm.err.log"
  )

  foreach ($p in $removePaths) {
    if (Test-Path $p) {
      Write-Host "Removing $p"
      try {
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
      } catch {
        $msg = $_.Exception.Message
        Write-Warning "Could not remove '${p}': ${msg}"
      }
    }
  }

  Write-Host "Done."
} finally {
  Pop-Location
}
