# Index

## Canonical plans

- `PLAN_V1.md`
  - execution plan for the app rebuild, phases, milestones, and v1 scope
- `ARCHITECTURE_DECISION.md`
  - locked v1 architecture and monetization direction
- `DATASET_ACQUISITION_PLAN.md`
  - dataset-first execution plan for the image benchmark, OCR bake-off, and
    classification foundation
- `DATA_SOURCE_MANIFEST.md`
  - ordered list of public and internal sources for the dataset phase
- `benchmark_schema.yaml`
  - machine-usable benchmark schema for image-first OCR and classification work
- `SYNTHETIC_SCREENSHOT_SPEC.md`
  - specification for generating the first synthetic screenshot benchmark
- `INDIA_DATASET_PLAN.md`
  - India-specific benchmark requirements for sender IDs, scam themes, and hard
    transactional false-positive cases
- `REFERENCE_TRANSCRIPT_PIPELINE.md`
  - multi-engine OCR consensus, LLM reconciliation, and manual fallback flow
- `LLM_RECONCILIATION_PROMPT.md`
  - reusable prompt template for Tier 2 OCR transcript reconciliation
- `scam app planning.md`
  - original product strategy note with market, monetization, and rollout intent

## Research

- `research/README.md`
  - research pack index and recommended reading order
- `research/MASTER_RESEARCH_PLAN.md`
  - merged research plan covering semantics, taxonomy, datasets, OCR, routing,
    and open questions
- `research/01-product-semantics.md`
  - output labels, explanation bar, next actions, guest-vs-account recommendation
- `research/02-categories-datasets-and-eval.md`
  - category taxonomy, dataset sources, benchmark structure, false-positive guidance
- `research/03-ocr-and-fallbacks.md`
  - OCR options, evaluation rubric, OCR failure handling, premium fallback logic
- `research/04-model-routing-and-thresholds.md`
  - first-pass / second-pass classifier plan, threshold calibration approach
- `research/05-external-model-prompts.md`
  - prompts for Gemini, Claude, or Grok to deepen specific research tracks

## Preserved assets

- `salvageable/README.md`
  - archive of the parts worth reusing from the previous repo
- `salvageable/architecture/ocr-flutter-android-v1.md`
  - OCR architecture note preserved from the old work
- `salvageable/infra/`
  - LiteLLM setup and run helpers
- `salvageable/scripts/`
  - dev checks and cleanup scripts
- `salvageable/github/`
  - CI and dependabot workflow fragments

## Current status

The repo is currently in planning mode. There is no active app implementation in
the root yet.
