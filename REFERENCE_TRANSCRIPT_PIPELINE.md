# Reference Transcript Pipeline

## Objective

Generate a usable reference transcript set for OCR benchmarking without manually
transcribing every real image up front.

The reference set exists to compare mobile/local OCR engines fairly. It does not
need to start as perfect human-labeled gold for every image, but it must be
systematic and auditable.

## Core principle

Use stronger non-mobile OCR systems for reference generation, then escalate only
the disagreements:

1. multi-engine OCR consensus
2. LLM reconciliation for non-consensus cases
3. manual annotation only for unresolved leftovers

## Tiers

### Tier 1: OCR consensus

Run at least three stronger OCR systems over the same image set.

Current planned research engines:

1. RapidOCR
2. Tesseract
3. EasyOCR

For each image:

- normalize outputs
- compare pairwise agreement
- compare critical-span agreement
- auto-accept a reference candidate when agreement is strong enough

### Tier 2: LLM reconciliation

Use an LLM only for images that fail Tier 1 auto-accept.

The LLM receives:

- image path
- all OCR engine outputs
- critical spans extracted from each output
- reconciliation instructions

The LLM should produce:

- one best-effort reference transcript
- confidence note
- whether the image should still be manually reviewed

### Tier 3: Manual annotation

Use manual transcription only for:

- images where OCR systems disagree materially
- images where critical scam spans conflict
- images where the LLM reconciliation is still weak
- visually broken screenshots where machine extraction is clearly unreliable

## Acceptance logic

Tier 1 auto-accept should require both:

- high pairwise transcript agreement
- acceptable critical-span agreement

Recommended starting thresholds:

- auto-accept if average pairwise normalized similarity is `>= 0.90`
- otherwise send to LLM reconciliation if average pairwise similarity is `>= 0.60`
- if below that, send directly to manual review

Critical spans to track:

- URLs
- phone numbers
- OTP / short numeric codes
- money amounts
- email addresses

If transcript agreement is high but critical spans disagree, do not auto-accept.

## Output statuses

Each image should end in one of these states:

- `auto_accept`
- `llm_reconcile`
- `manual_review`
- `needs_more_ocr`

## Files in repo

- `scripts/build_reference_transcripts.py`
- `scripts/export_llm_reconciliation_batch.py`
- `scripts/run_tesseract_batch.py`
- `scripts/run_easyocr_batch.py`
- `scripts/run_rapidocr_batch.py`
- `docker/ocr/`

## Practical workflow

1. build the OCR evaluation manifest
2. run 3 OCR engines over the same sample set
3. merge predictions into reference candidates
4. auto-accept high-agreement cases
5. export disagreement cases for LLM reconciliation
6. manually annotate only the unresolved remainder

## Current recommendation

Use the current synthetic scored set as the hard benchmark base, and use this
pipeline to create reference transcripts for the real/stress image pool.

This gives us:

- fast research iteration
- limited human effort
- a benchmark process we can improve over time
- no need to manually transcribe every real screenshot before OCR comparison starts
