# Journey

Use this file as the continuity log between sessions.

## How to use

At the end of each work session, add:

- what was completed
- what changed
- what is blocked
- what should be done next
- any important decisions made that day

Keep entries short and dated.

## Current baseline

- architecture locked to:
  - local OCR
  - cheap hosted first-pass classifier
  - stronger hosted second-pass reasoning model
  - policy layer for final output
- app should stay lightweight for seniors on lower-end devices
- monetization direction:
  - free core flow
  - ads only after free-usage threshold
  - premium for advanced capability, not basic safety

## Current main focus

1. image-first scam dataset
2. OCR bake-off
3. classification evaluation

## Suggested session entry template

### YYYY-MM-DD

- Completed:
- Decisions:
- Open questions:
- Next:
- Suggested commit(s):

### 2026-03-12

- Completed:
  - locked v1 architecture to local OCR + cheap hosted first-pass + stronger hosted second-pass
  - created dataset planning and workspace docs
  - created benchmark schema and source manifest templates
  - downloaded and extracted UCI SMS Spam Collection
  - extracted manually provided Mendeley SMS phishing dataset
  - added Phish-IRIS archive and extracted a curated 128-image OCR-stress subset
  - removed the unusable full Phish-IRIS archive and kept only the curated subset
  - normalized UCI SMS Spam Collection into:
    - `data/interim/normalized/uci_sms_spam_collection_normalized.csv`
  - normalized Mendeley SMS phishing dataset into:
    - `data/interim/normalized/mendeley_sms_phishing_normalized.csv`
  - combined normalized text seeds into:
    - `data/interim/normalized/seed_pool_v0_1.csv`
  - created first synthetic batch manifest:
    - `data/interim/manifests/synthetic_batch_v0_1.csv`
  - added synthetic screenshot renderer:
    - `scripts/render_synthetic_batch.py`
  - rendered first synthetic screenshot batch:
    - `80` images under `data/synthetic/renders/v0_1/`
    - `data/interim/manifests/synthetic_render_manifest.csv`
  - added OCR benchmark scripts:
    - `scripts/build_ocr_eval_manifest.py`
    - `scripts/run_rapidocr_batch.py`
    - `scripts/evaluate_ocr_predictions.py`
  - built OCR benchmark inventory:
    - `data/benchmark/v0.1/metadata/ocr_eval_manifest.csv`
    - `626` rows total
  - installed `rapidocr-onnxruntime` and ran the first OCR baseline:
    - `80` scored synthetic samples
    - `20` stress-smoke samples
    - baseline note in `data/benchmark/v0.1/reports/rapidocr_baseline_v0_1.md`
  - added reference transcript pipeline assets:
    - `REFERENCE_TRANSCRIPT_PIPELINE.md`
    - `LLM_RECONCILIATION_PROMPT.md`
    - `scripts/build_reference_transcripts.py`
    - `scripts/export_llm_reconciliation_batch.py`
  - added disposable OCR Docker runners:
    - `docker/ocr/rapidocr/Dockerfile`
    - `docker/ocr/tesseract/Dockerfile`
    - `docker/ocr/easyocr/Dockerfile`
  - built initial reference transcript manifest:
    - `data/benchmark/v0.1/metadata/reference_transcript_manifest.csv`
    - initial status before more engines: all rows were `needs_more_ocr`
  - ran EasyOCR on the synthetic benchmark:
    - `data/benchmark/v0.1/reports/easyocr_predictions_v0_1.csv`
  - built and ran the disposable Tesseract Docker runner on the synthetic benchmark:
    - `data/benchmark/v0.1/reports/tesseract_predictions_v0_1.csv`
  - rebuilt the reference manifest using RapidOCR, EasyOCR, and Tesseract:
    - `65` auto-accepted
    - `14` sent to Gemini reconciliation
    - `1` direct manual-review holdout
  - ran Gemini reconciliation on the disagreement batch:
    - `13` resolved
    - `1` remained manual review
  - wrote resolved reference status outputs:
    - `data/benchmark/v0.1/metadata/reference_transcript_manifest_resolved.csv`
    - `data/benchmark/v0.1/reports/reference_transcript_resolved_summary.csv`
    - `data/benchmark/v0.1/reports/reference_transcript_status_v0_1.md`
- Decisions:
  - do not ship a large local classifier such as MobileBERT in v1
  - dataset, OCR, and classification are the active foundation priorities
- Open questions:
  - how ML Kit will compare against the current three-engine synthetic baseline
  - how quickly we can generate second and third OCR outputs for the `546` stress or real images
- Next:
  - generate additional OCR outputs for the `546` stress or real images
  - rebuild the reference manifest for that larger pool
  - export remaining disagreement cases for Gemini reconciliation
  - use CIRCL and the pruned Phish-IRIS subset only as OCR stress sources
  - keep the `manual_curate` rows for later `unclear` case authoring
- Suggested commit(s):
  - `Build dataset workspace and curate OCR stress subsets`
  - `Normalize seed datasets and create first synthetic batch manifest`
  - `Render synthetic screenshot benchmark batch`
  - `Add OCR benchmark harness and first RapidOCR baseline`
  - `Add reference transcript pipeline and disposable OCR runners`
  - `Run three-engine OCR consensus and Gemini reconciliation`

### 2026-03-13

- Completed:
  - replaced the broken dashboard-control loop with a read-only dashboard plus a single baseline worker
  - added durable NVIDIA batch processing, merge logic, and worker state/logging
  - finished Phi-4 stress extraction to `546 / 546`
  - ran Phi-4 on the full `80` synthetic benchmark images
  - generated Phi-4 synthetic OCR detail/summary reports
  - demoted Scout from the active path and repurposed the second NVIDIA key/lane to help Phi-4
  - fixed the worker to use pending sample IDs instead of broken count-based offsets
- Decisions:
  - research extractors were only for baseline/reference creation, not for shipping OCR selection
  - active baseline path is now:
    - RapidOCR
    - Tesseract
    - Phi-4
    - Gemini reconciliation
    - manual review only for leftovers
  - Scout is removed from the active path
- Open questions:
  - Gemini reconciliation is still failing/rate-limited and needs one more pass before freeze
  - after Gemini, how many samples remain manual-review grade
- Next:
  1. finish one more Gemini reconciliation pass on the unresolved disagreement set
  2. freeze the baseline/reference set
  3. start mobile OCR evaluation
  4. compare candidate performance by:
     - latency
     - body recall
     - scam-span recall
     - failure rate
     - India vs US
     - SMS vs WhatsApp vs email-like
     - clean vs medium vs hard
- Suggested commit(s):
  - `Replace dashboard orchestration with read-only monitor and baseline worker`
  - `Finish Phi-4 synthetic benchmark and repurpose second NVIDIA lane`
