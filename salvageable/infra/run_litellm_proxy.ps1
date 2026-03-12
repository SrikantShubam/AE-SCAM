param(
  [string]$ConfigPath = "infra/nvidia-workers.litellm.yaml",
  [string]$EnvFile = ".env",
  [int]$Port = 0,
  [switch]$Debug,
  [switch]$Bootstrap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

function Resolve-RepoPath([string]$path) {
  if ([System.IO.Path]::IsPathRooted($path)) { return $path }
  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
  return (Join-Path $repoRoot $path)
}

function Import-DotEnv([string]$path) {
  if (-not (Test-Path $path)) {
    return
  }

  Get-Content $path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }

    $parts = $line.Split('=', 2)
    if ($parts.Count -ne 2) { return }

    $key = $parts[0].Trim()
    $value = $parts[1]

    if (-not $key) { return }
    [Environment]::SetEnvironmentVariable($key, $value, 'Process')
  }
}

function Require-Env([string]$name) {
  $value = [Environment]::GetEnvironmentVariable($name, 'Process')
  if (-not $value) {
    throw "Missing required environment variable: $name"
  }
}

$configAbs = Resolve-RepoPath $ConfigPath
$envAbs = Resolve-RepoPath $EnvFile

$venvLiteLLM = Resolve-RepoPath "infra/.venv/Scripts/litellm.exe"
if ($Bootstrap -or (-not (Test-Path $venvLiteLLM) -and -not (Get-Command litellm -ErrorAction SilentlyContinue))) {
  & (Resolve-Path (Join-Path $PSScriptRoot "setup_litellm_proxy.ps1"))
}

$litellmCmd = $null
if (Test-Path $venvLiteLLM) {
  $litellmCmd = $venvLiteLLM
} else {
  $systemCmd = Get-Command litellm -ErrorAction SilentlyContinue
  if ($systemCmd) {
    $litellmCmd = $systemCmd.Source
  }
}

if (-not $litellmCmd) {
  throw "Missing required command: litellm. Run ./infra/setup_litellm_proxy.ps1 or rerun with -Bootstrap."
}

Import-DotEnv $envAbs

Require-Env "LITELLM_MASTER_KEY"
Require-Env "NVIDIA_API_KEY"
Require-Env "NVIDIA_API_BASE_URL"
Require-Env "NVIDIA_MINIMAX25_MODEL"
Require-Env "NVIDIA_GLM47_MODEL"

if ($Port -le 0) {
  $portFromEnv = [Environment]::GetEnvironmentVariable("LITELLM_PORT", 'Process')
  if ($portFromEnv) { $Port = [int]$portFromEnv } else { $Port = 4001 }
}

$argsList = @("--config", $configAbs, "--port", "$Port")
if ($Debug) { $argsList += "--debug" }

Write-Host "Starting LiteLLM proxy on port $Port using $ConfigPath"
& $litellmCmd @argsList
