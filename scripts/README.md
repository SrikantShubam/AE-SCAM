# Scripts

- `render_synthetic_batch.py`: generates the first synthetic screenshot batch from `data/interim/manifests/synthetic_batch_v0_1.csv` and writes a render manifest to `data/interim/manifests/synthetic_render_manifest.csv`.
- `build_ocr_eval_manifest.py`: combines rendered synthetic images and stress datasets into `data/benchmark/v0.1/metadata/ocr_eval_manifest.csv`.
- `run_rapidocr_batch.py`: runs RapidOCR over the OCR eval manifest and writes predictions to `data/benchmark/v0.1/reports/`.
- `run_tesseract_batch.py`: runs Tesseract OCR over the OCR eval manifest.
- `run_easyocr_batch.py`: runs EasyOCR over the OCR eval manifest.
- `evaluate_ocr_predictions.py`: scores OCR predictions against gold text for the synthetic subset and writes detail and summary reports.
- `build_reference_transcripts.py`: merges multiple OCR output CSVs into auto-accepted, LLM-reconcile, and manual-review reference candidates.
- `export_llm_reconciliation_batch.py`: exports only the disagreement cases for LLM reconciliation.
- `run_llm_reconciliation.py`: sends disagreement cases to Gemini or an OpenAI-compatible endpoint and writes JSONL reconciliation results.
- `apply_llm_reconciliation.py`: merges LLM reconciliation results back into the main reference manifest.
