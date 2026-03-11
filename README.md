# ai_elderly_scam

Flutter app + local infra helpers.

## Prereqs

- Flutter `3.38.4` (Dart SDK must satisfy `pubspec.yaml`'s `environment.sdk` constraint; currently `>=3.10.3`)

## Dev checks

- Windows (PowerShell): `./scripts/check.ps1`
- macOS/Linux: `bash ./scripts/check.sh`
- To bypass the Flutter/Dart version guardrails:
  - PowerShell: `./scripts/check.ps1 -SkipVersionCheck`
  - Bash: `SKIP_FLUTTER_VERSION_CHECK=1 bash ./scripts/check.sh`

## Infra

See `infra/README.md` for running the local LiteLLM proxy.

## Clean

- Windows (PowerShell): `./scripts/clean.ps1`
- macOS/Linux: `bash ./scripts/clean.sh`

## Secrets

- Keep runtime secrets in a local `.env` (gitignored); start from `.env.example`.
- CI refuses to run if `.env` (or `infra/.venv`) is present in the repo checkout.
- If an API key ever lands in version control, rotate it immediately.
