# India Dataset Plan

## Objective

Build the India-specific benchmark slice required for:

- OCR selection
- classification evaluation
- false-positive control on legitimate Indian messages
- synthetic screenshot generation that matches real Indian message patterns

This is not optional. The India market cannot be represented well by generic SMS
spam datasets alone.

## Why India needs its own slice

India-specific message patterns differ materially from US-style SMS data:

- alphanumeric sender IDs are common
- bank and telecom alerts often use compressed transactional language
- UPI, KYC, PAN, Aadhaar, wallet, and telecom recharge themes matter
- legitimate alerts can look superficially scam-like
- mixed-script and transliterated content are common even in English-first usage

If we do not model this explicitly, false positives on legitimate Indian
messages will likely be too high.

## Core India benchmark goals

The India slice must help answer:

1. can OCR read Indian transactional screenshots reliably?
2. can the classifier distinguish Indian legitimate alerts from scams?
3. do sender IDs reduce or increase confusion?
4. how much mixed-script content breaks OCR or classification?

## Required India sample categories

### Legitimate transactional

These are critical because they are the biggest false-positive risk.

- bank OTP
- bank debit/credit alerts
- card transaction alerts
- UPI collect / payment notifications
- telecom recharge alerts
- SIM / mobile service notices
- courier / delivery updates
- account login alerts
- e-commerce order / delivery messages

### Scam / smishing

- fake KYC expiry alerts
- fake bank account freeze alerts
- fake UPI collect requests
- fake refund / cashback links
- fake telecom SIM block warnings
- fake delivery fee/payment requests
- fake government subsidy/tax refund claims
- credential theft via OTP / PIN / password request
- remote access / app install scams

### Ambiguous / hard-case

- bank alerts with links that may be legitimate
- UPI-related reminders without obvious scam language
- mixed marketing + payment request messages
- legitimate-looking service notices from unfamiliar sender IDs
- truncated screenshots where sender or context is partially missing

## India-specific features to represent

### Sender ID patterns

The dataset should include legitimate and scam examples using:

- alphanumeric sender IDs
- short codes
- normal phone numbers
- unknown or spoof-like sender formats

Examples to simulate:

- `HDFCBK`
- `SBIINB`
- `ICICIB`
- `PAYTMB`
- `JIOTEL`
- `VM-XXXXXX`
- `VK-XXXXXX`
- regular 10-digit mobile numbers

These are examples of format patterns, not a final whitelist.

### Financial language

Include realistic Indian financial terms:

- UPI
- KYC
- PAN
- Aadhaar
- account blocked
- account freeze
- wallet
- refund
- cashback
- collect request
- recharge
- debit / credit
- IMPS / NEFT / RTGS

### Currency and numbers

The dataset should include:

- `Rs`
- `INR`
- `₹`
- Indian digit grouping where relevant
- payment amounts in common scam ranges

### Mixed-language patterns

For v1 we are English only, but the India slice still must include:

- English messages with Indian service terms
- transliterated Hindi in Latin script
- mixed English + Hindi screenshot text for OCR stress

These should be separated clearly:

- classification benchmark core:
  - English and transliterated Latin-script content
- OCR stress and future-proofing:
  - mixed English + Devanagari or regional script content

## India data sources we need

### Public or semi-public seed material

Use any available sources for:

- Indian banking SMS examples
- telecom service alerts
- courier updates
- UPI/payment notifications
- known Indian smishing examples

These may need to be manually curated if they are not packaged as datasets.

### Internal synthetic generation

We will likely need to generate much of the India slice ourselves using:

- Indian sender formats
- Indian banking/payment vocabulary
- India-specific screenshot templates
- India-specific scam templates

### Real screenshot collection

We should collect or curate real Indian screenshots for:

- bank OTPs
- debit/credit notifications
- UPI notifications
- telecom alerts
- scam examples
- hard ambiguous cases

## Minimum India slice for benchmark v0.1

Recommended minimum:

- 80 India screenshot samples in the first benchmark

Suggested split:

- 30 legitimate transactional
- 30 scam
- 20 ambiguous / hard-case

Suggested channel split:

- 35 SMS
- 30 WhatsApp
- 15 email or other

Suggested quality split:

- 35 clean
- 25 medium
- 20 hard

## India synthetic screenshot requirements

The first synthetic India batch should include:

- SMS layouts with alphanumeric sender IDs
- WhatsApp screenshots with Indian scam language patterns
- INR amounts
- UPI/KYC themes
- bank/telecom examples
- both scam and legitimate messages

Hard variants should include:

- WhatsApp-forwarded compression look
- cropped sender IDs
- dark mode
- blur
- partial screenshots

## India OCR test requirements

For OCR, the India slice must test:

- sender ID extraction
- amount extraction
- URL extraction
- OTP extraction
- transliterated Hindi words in Latin script
- mixed-script screenshots as a separate OCR stress slice

## India classification requirements

The classifier must be evaluated separately on:

- Indian legitimate messages
- Indian scam messages
- Indian ambiguous messages

Required failure analysis:

- false positives on bank/OTP/UPI alerts
- false negatives on fake KYC / fake account freeze scams
- confusion caused by alphanumeric sender IDs

## India-specific open questions

- which legitimate Indian sender ID patterns most often confuse the classifier?
- which Indian scam themes are most common in screenshot form?
- how much mixed-script content matters for launch vs later hardening?
- do UPI and KYC scam variants require their own subcategory tags internally?

## Immediate next actions

1. create an India seed-message list
2. create India-specific synthetic screenshot templates
3. define India-specific legitimate message pool
4. define India-specific scam message pool
5. mark India samples explicitly in the benchmark manifest

## Success condition

The India dataset slice is good enough for the first OCR and classification pass
when:

- it includes both scam and legitimate transactional messages
- it includes real sender ID patterns
- it includes UPI/KYC/bank/telecom themes
- it includes enough hard cases to expose false positives
