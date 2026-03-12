# Dataset Acquisition Plan

## Objective

Build the image-first benchmark that will drive the next three foundation
 objectives:

1. scam screenshot dataset
2. OCR bake-off
3. classification evaluation

The target is not a generic text dataset. The target is a benchmark that looks
like the real app input:

- SMS screenshots
- WhatsApp screenshots
- email screenshots
- image quality variations
- India and US formats
- English only in v1

## Current conclusion

There is no strong public open dataset that already matches the product need as
an image-first senior-focused scam screenshot benchmark.

So the right strategy is a hybrid:

1. public text datasets as seed content
2. public phishing screenshot datasets as OCR stress data only
3. internal screenshot generation for controlled benchmark creation
4. internal real-screenshot collection for production realism

## What the ideal dataset must contain

### Core requirements

- image-first samples, not just text
- labels:
  - `scam`
  - `not_scam`
  - `unclear`
- top-level categories:
  - impersonation
  - credential theft
  - payment extraction
  - tech support / device compromise
  - emotion / pressure fraud
- market tags:
  - `india`
  - `us`
- channel tags:
  - `sms`
  - `whatsapp`
  - `email`
- image quality tiers:
  - `clean`
  - `medium`
  - `hard`

### OCR-specific fields

- gold text
- OCR output
- OCR edit distance
- scam-span labels
  - URL
  - phone number
  - payment amount
  - OTP / code

## Public sources we can use now

### 1. UCI SMS Spam Collection

Use for:

- legitimate/spam SMS text seeds
- synthetic screenshot rendering

Limits:

- text only
- old
- not scam-screenshot-native

Source:

- https://archive.ics.uci.edu/dataset/228

### 2. Mendeley SMS Phishing Dataset

Use for:

- smishing-oriented text seeds
- synthetic screenshot rendering

Limits:

- text only in the published artifact
- images were converted to text upstream, so it does not solve our screenshot
  benchmark problem directly

Source:

- https://data.mendeley.com/datasets/f45bkkt8pr/1

### 3. Phish-Iris

Use for:

- OCR/image robustness experiments
- screenshot-style phishing image stress tests

Limits:

- web page phishing screenshots, not message screenshots
- not directly representative of SMS/WhatsApp product input

Source:

- https://data.mendeley.com/datasets/tk4fkswtj5/1

### 4. CIRCL phishing screenshot dataset

Use for:

- OCR robustness experiments
- image-only phishing screenshot stress testing

Limits:

- phishing website screenshots, not mobile message screenshots
- small

Source:

- https://www.circl.lu/opendata/circl-phishing-dataset-01/

## Explicitly excluded source

### Sting9

Status:

- excluded from the active dataset path

Reason:

- low-confidence data quality for our needs
- no practical self-serve registration/export path available right now
- not worth blocking the benchmark foundation work

Reference only:

- https://sting9.org/dataset

## Useful collection channels, not benchmark-ready datasets

### APWG smishing submission workflow

Useful because it confirms screenshot-based reporting is realistic and common,
but it is not an open ready-to-train dataset we can directly rely on.

Source:

- https://www.apwg.org/sms

## Recommended dataset strategy

### Layer 1: Seed text corpus

Build a text seed pool from:

- UCI SMS Spam Collection
- Mendeley SMS Phishing Dataset

Purpose:

- scam category coverage
- benign transactional coverage
- initial classifier training and analysis

### Layer 2: Synthetic screenshot benchmark

Render text seeds into realistic mobile screenshots:

- Android SMS style
- WhatsApp style
- email inbox / opened email style
- India sender ID patterns
- US phone number / short code patterns

Add controlled variations:

- dark mode
- blur
- crop
- compression
- forwarded / re-saved image quality
- font-size variation

Purpose:

- fast OCR comparison
- controlled experiments
- scalable benchmark growth

### Layer 3: Real screenshot benchmark

Collect real screenshots internally or through trusted testers:

- suspicious SMS
- suspicious WhatsApp messages
- suspicious emails
- legitimate OTP / bank / delivery / account alerts

Requirements:

- PII handling workflow
- annotation process
- consent if sourced from real users
- redaction rules before long-term retention

Purpose:

- final OCR decision
- final threshold calibration
- hard-case validation

## What we should build first

### Stage A: MVP benchmark

Goal:

- enough data to start OCR comparison

Recommended composition:

- 200 screenshot samples total
- 100 synthetic
- 100 real or manually curated screenshot-like samples

Suggested split:

- 40% scam
- 40% legitimate transactional
- 20% unclear / hard cases

### Stage B: Production benchmark

Goal:

- enough data to choose OCR and tune classification

Recommended composition:

- 500+ screenshot samples
- stratified by market, channel, and quality tier

## Exact deliverables for the dataset phase

1. benchmark schema
2. source inventory
3. synthetic screenshot generation plan
4. real-screenshot collection protocol
5. annotation guide
6. initial benchmark manifest

## Decision

Do not wait for a perfect open screenshot dataset.

The correct move is:

1. use public text datasets immediately
2. render them into screenshot-like benchmark data
3. collect real screenshots in parallel
4. use phishing screenshot datasets only as OCR stress supplements

## Immediate next actions

1. define the benchmark schema in a machine-usable format
2. list exact public sources to ingest first
3. define synthetic screenshot templates
4. define the annotation workflow

## Sources

- UCI SMS Spam Collection: https://archive.ics.uci.edu/dataset/228
- Mendeley SMS Phishing Dataset: https://data.mendeley.com/datasets/f45bkkt8pr/1
- Phish-Iris screenshot dataset: https://data.mendeley.com/datasets/tk4fkswtj5/1
- CIRCL phishing screenshot dataset: https://www.circl.lu/opendata/circl-phishing-dataset-01/
- APWG smishing reporting: https://www.apwg.org/sms
