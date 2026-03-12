# LLM Key Setup

## Recommended providers for March 2026

1. `Gemini`
   - best first choice for transcript reconciliation
   - supports image-aware reconciliation if we enable `--include-image`
2. `NVIDIA`
   - strong research-path OCR or model tooling depending on the endpoint you have

## Environment variables

### Gemini

Set either:

- `GOOGLE_API_KEY`
- `GEMINI_API_KEY`

### NVIDIA / generic OpenAI-compatible endpoint

Set one of:

- `NVIDIA_API_KEY`
- `OPENAI_COMPAT_API_KEY`

And pass the base URL explicitly when running the script.

## Example commands

### Gemini text-plus-image reconciliation

```powershell
$env:GOOGLE_API_KEY="..."
python scripts/run_llm_reconciliation.py `
  --provider gemini `
  --model gemini-2.5-flash `
  --batch data/benchmark/v0.1/metadata/llm_reconciliation_batch.jsonl `
  --output data/benchmark/v0.1/reports/llm_reconciliation_gemini.jsonl `
  --include-image
```

### NVIDIA or other OpenAI-compatible endpoint

```powershell
$env:NVIDIA_API_KEY="..."
python scripts/run_llm_reconciliation.py `
  --provider openai_compat `
  --model <your-model-name> `
  --base-url <your-base-url> `
  --batch data/benchmark/v0.1/metadata/llm_reconciliation_batch.jsonl `
  --output data/benchmark/v0.1/reports/llm_reconciliation_openai_compat.jsonl
```

## Current recommendation

Use Gemini first for reconciliation once the disagreement batch exists.
