# Data Download Checklist

## Objective

This checklist defines what should be placed into the repo before ingestion and
what can be created internally without download.

## Public sources to acquire

### 1. UCI SMS Spam Collection

- Target folder:
  - `data/raw/public/uci_sms_spam_collection/`
- Purpose:
  - baseline text seeds for scam/not-scam messages

### 2. Mendeley SMS Phishing Dataset

- Target folder:
  - `data/raw/public/mendeley_sms_phishing/`
- Purpose:
  - smishing-oriented text seeds

### 3. Sting9 export or curated extract

- Target folder:
  - `data/raw/public/sting9/`
- Purpose:
  - richer scam/phishing examples and metadata

### 4. OCR stress datasets

- Target folders:
  - `data/raw/stress/phish_iris/`
  - `data/raw/stress/circl_phishing_dataset_01/`
- Purpose:
  - OCR stress testing only

## What does not require download

### Synthetic screenshots

These are generated internally from seed text.

Target folders:

- `data/synthetic/templates/`
- `data/synthetic/renders/`

### Benchmark metadata

These are created internally.

Target folders:

- `data/interim/manifests/`
- `data/benchmark/v0.1/metadata/`

## What may require manual collection later

### Real screenshot benchmark

Target folder:

- `data/raw/internal/`

Notes:

- may contain sensitive data
- should be redacted and handled carefully
- should not be committed by default

## Intake rule

After any dataset is added locally, the next step is:

1. record it in the source manifest
2. normalize it into a common schema
3. decide whether it is:
   - seed text
   - screenshot benchmark data
   - OCR stress data
