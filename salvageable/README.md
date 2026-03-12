# Salvageable Assets

This folder contains the only parts of the previous repo worth keeping.

## Kept

- `architecture/ocr-flutter-android-v1.md`
  - concrete OCR direction for Android v1
- `infra/`
  - LiteLLM proxy setup, run scripts, and pinned dependency file
- `scripts/`
  - dev check and cleanup scripts with version and hygiene guardrails
- `github/`
  - reusable CI and dependency update workflow fragments
- `.env.example`
  - local environment variable template

## Not Kept

The old Flutter app scaffold, tests, Android project, generated files, and
logs were removed because they were either broken, template-level, or not part
of a reliable product base.

## Rule

Do not edit files here as if they are active product code. Treat this directory
as an archive of reusable components for the rebuild.
