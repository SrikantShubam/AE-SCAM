# OCR Bake-off Plan

## Objective

Compare the OCR engines we may ship using the first image-first benchmark.

## Engines to compare first

1. ML Kit Text Recognition v2
2. PaddleOCR mobile-friendly variant
3. Tesseract baseline

## Research-grade extraction engines for benchmark generation

These are not assumed shipping candidates for the app. They are included to
help create a stronger evaluation benchmark and to stress the local OCR
engines against stronger extraction systems.

1. NVIDIA `microsoft/phi-4-multimodal-instruct`
2. NVIDIA `meta/llama-4-scout-17b-16e-instruct`
3. NVIDIA Image OCR / OCR NIM
4. Mistral OCR
5. Google Cloud Vision OCR
6. Azure AI Vision Read OCR
7. Gemini document-image extraction path

## Decision goal

Choose the OCR path for v1 based on benchmark performance, not intuition.

## Evaluation inputs

Use benchmark `v0.1` with:

- synthetic screenshots
- real screenshots if available
- OCR stress images as supplemental tests only

## Primary metric

Scam-span extraction accuracy:

- URL correctness
- phone number correctness
- payment amount correctness
- OTP/code correctness

## Secondary metrics

- overall OCR text quality
- blank/null output rate
- latency
- cold start behavior
- implementation complexity
- app size impact

## Required slices

- India clean
- India hard
- India mixed-script
- US clean
- US hard
- WhatsApp forwarded/compressed
- scam-relevant span subset

## Output format

Each OCR engine should produce:

- OCR output file
- normalized metrics
- span-accuracy report
- per-slice summary
- final recommendation note

## Decision rules

- if ML Kit passes required floors on all important slices, keep ML Kit
- if ML Kit fails mainly on India mixed-script, evaluate whether PaddleOCR is
  worth a market-specific path
- if all engines fail badly on hard slices, tighten the OCR quality gate and
  rely more on paste-text recovery instead of forcing classification

## Immediate next tasks

1. ~~create the OCR output manifest schema~~
2. ~~define benchmark sample selection for the first bake-off~~
3. ~~define how latency will be measured~~
4. run additional OCR engines against the same manifest
5. define pass/fail thresholds before comparing shipping candidates
6. add NVIDIA OCR into the benchmark-generation task list
7. add at least two newer hosted OCR extractors for research-only comparison
