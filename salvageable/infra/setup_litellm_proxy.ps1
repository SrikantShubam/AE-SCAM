param(
  [string]$RequirementsPath = "infra/requirements.txt",
  [string]$VenvDir = "infra/.venv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoPath([string]$path) {
  if ([System.IO.Path]::IsPathRooted($path)) { return $path }
  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
  return (Join-Path $repoRoot $path)
}

function Assert-Command([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

function Resolve-PythonCommand() {
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python) { return @{ Exe = $python.Source; Args = @() } }

  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py) { return @{ Exe = $py.Source; Args = @("-3") } }

  throw "Missing required command: python (or py -3)"
}

$pythonCmd = Resolve-PythonCommand

$requirementsAbs = Resolve-RepoPath $RequirementsPath
$venvAbs = Resolve-RepoPath $VenvDir

if (-not (Test-Path $requirementsAbs)) {
  throw "Missing requirements file: $requirementsAbs"
}

if (-not (Test-Path $venvAbs)) {
  Write-Host "Creating venv at $venvAbs"
  & $pythonCmd.Exe @($pythonCmd.Args + @("-m", "venv", $venvAbs))
}

$venvPython = Join-Path $venvAbs "Scripts/python.exe"
if (-not (Test-Path $venvPython)) {
  throw "Venv python not found at: $venvPython"
}

Write-Host "Upgrading pip"
& $venvPython -m pip install --upgrade pip

Write-Host "Installing infra dependencies from $requirementsAbs"
& $venvPython -m pip install -r $requirementsAbs

$venvLiteLLM = Join-Path $venvAbs "Scripts/litellm.exe"
if (-not (Test-Path $venvLiteLLM)) {
  throw "LiteLLM CLI not found after install at: $venvLiteLLM"
}

Write-Host "LiteLLM proxy dependencies are ready."
