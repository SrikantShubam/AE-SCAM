# Reference Transcript Status v0.1

## Scope

This status reflects the current reference transcript pipeline state after:

- RapidOCR on the synthetic benchmark
- EasyOCR on the synthetic benchmark
- Tesseract on the synthetic benchmark
- Gemini reconciliation on the disagreement subset

## Current status counts

- `auto_accept`: `65`
- `llm_resolved`: `13`
- `manual_review`: `2`
- `needs_more_ocr`: `546`

## Interpretation

- `78 / 80` synthetic screenshots now have a resolved reference transcript from
  either direct OCR consensus or Gemini reconciliation.
- `2 / 80` synthetic screenshots remain marked `manual_review`.
  - one is a low-agreement synthetic sample, but synthetic gold text already
    exists in the manifest
  - one is a true unresolved hard case with conflicting critical spans
- `546` stress/real images still need more OCR passes before the reference
  transcript pipeline can classify them beyond `needs_more_ocr`

## Main files

- `data/benchmark/v0.1/metadata/reference_transcript_manifest.csv`
- `data/benchmark/v0.1/metadata/reference_transcript_manifest_resolved.csv`
- `data/benchmark/v0.1/metadata/llm_reconciliation_batch.jsonl`
- `data/benchmark/v0.1/reports/llm_reconciliation_gemini.jsonl`
- `data/benchmark/v0.1/reports/reference_transcript_resolved_summary.csv`

## Next step

Run additional OCR passes on the `546` stress/real images, then rebuild the
reference manifest and export only the remaining disagreement cases for LLM
reconciliation.
