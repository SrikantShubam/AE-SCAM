# Data Workspace

## Purpose

This file defines where raw data, processed benchmark data, and generated
synthetic screenshots should live in the repo.

## Folder structure

```text
data/
  raw/
    public/
    internal/
    stress/
  interim/
    normalized/
    manifests/
  synthetic/
    templates/
    renders/
  benchmark/
    v0.1/
      samples/
      metadata/
      reports/
```

## Meaning of each folder

### `data/raw/public/`

Public source files downloaded from:

- UCI SMS Spam Collection
- Mendeley SMS Phishing Dataset
- Sting9 exports or source extracts

These files should remain unchanged after download.

### `data/raw/internal/`

Internal manually curated or tester-provided screenshots.

This folder may contain sensitive data. Do not commit anything here unless it is
redacted and explicitly intended for version control.

### `data/raw/stress/`

Image/OCR stress sources such as:

- Phish-Iris
- CIRCL phishing screenshot dataset

These are not the core benchmark, but they help pressure-test OCR.

### `data/interim/normalized/`

Normalized text exports and transformed metadata derived from raw sources.

### `data/interim/manifests/`

CSV or JSONL manifests describing:

- which source files were ingested
- which synthetic screenshots were rendered
- which samples entered benchmark versions

### `data/synthetic/templates/`

Reusable render templates for:

- SMS
- WhatsApp
- email

### `data/synthetic/renders/`

Generated screenshot images used for OCR and classification benchmarking.

### `data/benchmark/v0.1/`

Benchmark version root.

Suggested contents:

- `samples/` for images or text samples included in the benchmark
- `metadata/` for benchmark manifests and labels
- `reports/` for OCR/model evaluation outputs

## Git hygiene

- keep sensitive raw internal screenshots out of git
- keep synthetic benchmark artifacts in git only if size remains manageable
- keep manifests, schemas, and normalized metadata in git
- if large files appear, switch to an external storage strategy rather than
  bloating the repo

## Immediate rule

Before ingesting any dataset, place it in the correct `data/raw/...` folder and
record it in the manifest.
