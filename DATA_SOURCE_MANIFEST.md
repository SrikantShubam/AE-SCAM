# Data Source Manifest

## Purpose

This file lists the exact data sources to ingest or use during the dataset
phase, in the order they should be touched.

## Tier 1: Ingest immediately

These sources are useful now and should seed the first benchmark work.

### 1. UCI SMS Spam Collection

- Role:
  - baseline SMS text seed source
- Use for:
  - legitimate and spam text seeds
  - synthetic screenshot generation
- Notes:
  - older dataset, so do not treat it as a full modern benchmark
- Link:
  - https://archive.ics.uci.edu/dataset/228

### 2. Mendeley SMS Phishing Dataset

- Role:
  - smishing-oriented text seed source
- Use for:
  - phishing/smishing text seeds
  - synthetic screenshot generation
- Notes:
  - text-centric for our purposes
- Link:
  - https://data.mendeley.com/datasets/f45bkkt8pr/1

## Tier 2: Use as OCR stress supplements

These are useful for image/OCR difficulty, not as the main product benchmark.

### 3. Phish-Iris

- Role:
  - image stress source
- Use for:
  - OCR robustness experiments
  - screenshot-like phishing image tests
- Notes:
  - web phishing screenshots, not message screenshots
- Link:
  - https://data.mendeley.com/datasets/tk4fkswtj5/1

### 4. CIRCL phishing screenshot dataset

- Role:
  - image stress supplement
- Use for:
  - OCR stress checks
  - screenshot-image pipeline tests
- Notes:
  - small and not message-native
- Link:
  - https://www.circl.lu/opendata/circl-phishing-dataset-01/

## Tier 3: Operational reference

### 5. APWG smishing submission workflow

- Role:
  - confirms screenshot-based scam reporting is realistic
- Use for:
  - product context
  - future collection/reference workflow ideas
- Link:
  - https://www.apwg.org/sms

## Internal sources we must create

These are mandatory because public sources are not enough.

### A. Synthetic screenshot corpus

- Generate screenshot-like assets from text seeds
- Cover:
  - SMS
  - WhatsApp
  - email
  - India sender IDs
  - US sender patterns
  - clean / medium / hard quality

### B. Real screenshot collection

- Gather real screenshots from trusted testers or internal curation
- Include:
  - scam samples
  - legitimate OTP messages
  - legitimate bank alerts
  - delivery / courier messages
  - ambiguous or mixed-signal cases

## First ingestion order

1. UCI SMS Spam Collection
2. Mendeley SMS Phishing Dataset
3. internal synthetic screenshot generation
4. internal real screenshot collection
5. Phish-Iris and CIRCL for OCR stress only

## Excluded for now

### Sting9

- Status:
  - intentionally excluded
- Reason:
  - data quality concerns
  - no practical download or registration path available right now
- Link:
  - https://sting9.org/dataset
